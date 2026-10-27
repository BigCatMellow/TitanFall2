use std::{collections::{HashMap, HashSet}, fs, path::PathBuf};
use once_cell::sync::{Lazy, OnceCell};
use parking_lot::Mutex;
use rrplug::{prelude::*, bindings::class_types::{client::{CClient, SignonState}, cplayer::CPlayer}};
use crate::bindings::ENGINE_FUNCTIONS;
use super::preset_file;

#[derive(Default)]
struct State { allowed: HashSet<String>, hashes: HashMap<String,u64>, next_save: f32 }
static STATE: Lazy<Mutex<State>>=Lazy::new(||Mutex::new(State::default()));
static OPTION: OnceCell<ConVarStruct>=OnceCell::new();
pub(super) fn begin_map() { let mut state=STATE.lock(); state.allowed.clear(); state.next_save=0.; }

fn profile() -> PathBuf {
    std::env::args().find_map(|s|s.strip_prefix("-profile=").map(PathBuf::from)).unwrap_or_else(||PathBuf::from("R2Northstar"))
}
fn enabled() -> bool {
    let args: Vec<_>=std::env::args().collect();
    let loopback=args.windows(2).any(|p|p[0]=="-ip" && p[1]=="127.0.0.1");
    loopback && OPTION.get().is_some_and(ConVarStruct::get_value_bool)
}
fn schema() -> Result<u64,String> {
    fs::read(profile().join("runtime/compiled/cfg/server/persistent_player_data_version_231.pdef"))
        .map(|data|preset_file::fingerprint(&data)).map_err(|e|e.to_string())
}
fn owner(client: &CClient) -> Option<String> {
    // Read the underlying byte; only READY_INSECURE (3) is eligible.
    let ready=unsafe{std::ptr::addr_of!(client.m_nPersistenceState).cast::<u8>().read()};
    if client.m_bFakePlayer || client.m_nHandle!=1 || ready!=3 { return None; }
    let uid=crate::utils::get_c_char_array(&client.m_UID)?;
    preset_file::valid_owner(uid).then(||uid.to_owned())
}
fn path(uid: &str) -> PathBuf { profile().join("save_data/BT7274.LocalPersistence").join(format!("{uid}.bin")) }
pub(super) fn register(token: EngineToken) {
    _=OPTION.set(ConVarStruct::try_new(&ConVarRegister::new("bot_local_presets","0",
        rrplug::bindings::cvar::convar::FCVAR_GAMEDLL as i32,
        "save local-only human player persistence; requires explicit loopback binding"),token)
        .expect("register bot_local_presets"));
}

#[rrplug::sqfunction(VM="Server", ExportName="BT7274RestoreLocalPresets")]
pub(super) fn restore(player: Option<&mut CPlayer>) -> bool {
    if !enabled() { return false; }
    let Some(player)=player else {return false;};
    if shared::utils::get_player_index(player)!=0 {return false;}
    let Some(client)=(unsafe{ENGINE_FUNCTIONS.wait().client_array.as_mut()}) else {return false;};
    let Some(uid)=owner(client) else {return false;};
    let mut state=STATE.lock();
    state.allowed.remove(&uid); state.next_save=0.;
    let schema=match schema(){Ok(s)=>s,Err(e)=>{log::error!("LOCAL_PRESETS schema unavailable: {e}");return false;}};
    let file=match fs::read(path(&uid)) {
        Ok(file)=>file,
        Err(e) if e.kind()==std::io::ErrorKind::NotFound=>{
            state.allowed.insert(uid);log::info!("LOCAL_PRESETS first local profile; autosave enabled");return false;
        },
        Err(e)=>{log::error!("LOCAL_PRESETS load failed; existing file preserved: {e}");return false;}
    };
    let payload=match preset_file::decode(&file,&uid,schema){Ok(p)=>p,Err(e)=>{
        log::error!("LOCAL_PRESETS refused restore/autosave: {e}");return false;
    }};
    for (target,byte) in client.m_PersistenceBuffer.iter_mut().zip(payload) {*target=*byte as i8;}
    state.hashes.insert(uid.clone(),preset_file::fingerprint(payload));
    state.allowed.insert(uid);
    log::info!("LOCAL_PRESETS restored {} bytes before initialization; schema={schema:016X}",payload.len());
    true
}

#[rrplug::sqfunction(VM="Server", ExportName="BT7274SaveLocalPresets")]
pub(super) fn save(player: Option<&mut CPlayer>) -> bool {
    if player.is_none_or(|p|shared::utils::get_player_index(p)!=0){return false;}
    save_now()
}

fn save_now() -> bool {
    if !enabled(){return false;}
    let Some(client)=(unsafe{ENGINE_FUNCTIONS.wait().client_array.as_ref()}) else{return false;};
    let Some(uid)=owner(client) else{return false;};
    let mut state=STATE.lock();
    if !state.allowed.contains(&uid){return false;}
    let bytes:Vec<_>=client.m_PersistenceBuffer.iter().map(|b|*b as u8).collect();
    if !bytes.iter().any(|b|*b!=0){return false;}
    let hash=preset_file::fingerprint(&bytes);
    if state.hashes.get(&uid)==Some(&hash){return true;}
    let result=schema().and_then(|schema|preset_file::encode(&uid,schema,&bytes).map_err(str::to_owned))
        .and_then(|file|preset_file::atomic_write(&path(&uid),&file).map_err(|e|e.to_string()));
    match result {
        Ok(())=>{state.hashes.insert(uid,hash);log::info!("LOCAL_PRESETS saved {} bytes; checksum={hash:016X}",bytes.len());true},
        Err(e)=>{log::error!("LOCAL_PRESETS save failed: {e}");false}
    }
}
pub(super) fn autosave() {
    if !enabled(){return;}
    let funcs=ENGINE_FUNCTIONS.wait();
    let Some(client)=(unsafe{funcs.client_array.as_ref()}) else{return;};
    if client.m_nSignonState!=SignonState::FULL{return;}
    let now=unsafe{funcs.globals.as_ref()}.map_or(0.,|g|g.curTime);
    {
        let mut state=STATE.lock();
        if now<state.next_save{return;}
        state.next_save=now+2.;
    }
    _=save_now();
}
