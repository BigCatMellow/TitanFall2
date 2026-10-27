import test from 'node:test';
import assert from 'node:assert/strict';
import {analyzeNotes,parseNote} from '../tools/weapon-notes.mjs';
const ctx={type:'WNOTE_CONTEXT',map:'mp_eden',mode:'normal_play',tick:'0.016667'};
const hit=(id,t,hp,after,extra={})=>[
  {type:'WNOTE_HIT',event:String(id),t:String(t),victim:'20',life:'1',attacker:'10',attacker_life:'1',akind:'human',vkind:'bot',atitan:'false',ateam:'2',vteam:'3',gun:'mp_weapon_rspn101',mods:'bt7274_solo_reload',config:'false:true:false:true:true',hp:String(hp),max_hp:'100',range:'400',hitgroup:'2',crit_scale:'1',force:'false',avx:'0',avy:'0',vvx:'0',vvy:'0',...extra},
  {type:'WNOTE_POST',event:String(id),t:String(t),victim:'20',life:'1',hp_after:String(after)}];
const death=(id,t)=>({type:'WNOTE_DEATH',event:String(id),t:String(t),victim:'20',life:'1'});
const clean=()=>[ctx,...hit(1,1,100,75),...hit(2,1.1,75,50),...hit(3,1.2,50,25),...hit(4,1.3,25,0),death(4,1.3)];
test('steady four-hit case is a health-damage span, not shot count or trigger TTK',()=>{const r=analyzeNotes(clean());assert.equal(r.clean_health_episodes,1);assert.ok(Math.abs(r.groups[0].median_s-0.3)<1e-9);assert.equal(r.deaths[0].damage_events,4);assert.match(r.metric,/health_damage/);});
test('shared damage never becomes a clean single-attacker sample',()=>{const a=clean();a[3].attacker='11';const r=analyzeNotes(a);assert.equal(r.clean_health_episodes,0);assert.ok(r.deaths[0].exclusions.includes('multiple_attackers'));});
test('injured targets, healing and missing damage are flagged',()=>{for(const [hp,reason]of [[90,'not_full_100hp_start']]){const a=clean();a[1].hp=String(hp);assert.ok(analyzeNotes(a).deaths[0].exclusions.includes(reason));}const heal=[ctx,...hit(1,1,100,75),...hit(2,2,90,0),death(2,2)];assert.ok(analyzeNotes(heal).deaths[0].exclusions.includes('healing_observed'));const gap=[ctx,...hit(1,1,100,75),...hit(2,2,50,0),death(2,2)];assert.ok(analyzeNotes(gap).deaths[0].exclusions.includes('unaccounted_health_loss'));});
test('weapon/mod/config changes stay ineligible',()=>{for(const [key,value,reason]of [['gun','mp_weapon_car','multiple_weapons'],['mods','other','changed_configuration'],['config','off','changed_configuration']]){const a=clean();a[3][key]=value;assert.ok(analyzeNotes(a).deaths[0].exclusions.includes(reason));}});
test('respawn and context boundaries cannot join separate lives/maps',()=>{const a=clean();a.splice(3,0,{type:'WNOTE_LIFE',victim:'20',life:'2'});assert.equal(analyzeNotes(a).clean_health_episodes,0);const b=clean();b.splice(3,0,ctx);assert.equal(analyzeNotes(b).clean_health_episodes,0);});
test('zero-loss damage does not create a kill measurement; missing final post rejected',()=>{assert.equal(analyzeNotes([ctx,...hit(1,1,100,100)]).death_records,0);const a=clean();a.splice(a.length-2,1);assert.equal(analyzeNotes(a).clean_health_episodes,0);});
test('forced kills, friendly/self damage, Titans and unknown sources are segregated',()=>{for(const extra of [{force:'true'},{attacker:'20'},{ateam:'3'},{atitan:'true'},{gun:'unknown'},{mods:'unknown'}]){const a=clean();Object.assign(a[1],extra);assert.equal(analyzeNotes(a).clean_health_episodes,0);}});
test('one-tick kills retain zero spans without inventing shots; logger errors are visible',()=>{const r=analyzeNotes([ctx,...hit(1,1,100,0),death(1,1),{type:'WNOTE_ERROR'}]);assert.equal(r.deaths[0].damage_span_s,0);assert.equal(r.deaths[0].single_tick_span,true);assert.equal(r.logger_errors,1);});
test('overwritten same-frame records cannot qualify as a clean episode',()=>{const a=clean();a.splice(4,0,{type:'WNOTE_GAP',event:'2'});assert.ok(analyzeNotes(a).deaths[0].exclusions.includes('missing_post_damage'));const b=clean();b.splice(2,1);assert.equal(analyzeNotes(b).clean_health_episodes,0);});
test('parser ignores unrelated/auth logs and preserves only structured fields',()=>{assert.equal(parseNote('token_url secret'),null);assert.equal(parseNote('stack print("WNOTE_DEATH t=1")'),null);assert.deepEqual(parseNote('[info] WNOTE_DEATH t=1 victim=20 life=1 event=2'),{type:'WNOTE_DEATH',t:'1',victim:'20',life:'1',event:'2'});});
test('opt-in expenditure stays separate across mods and maps',()=>{
  const fire=(rounds,ads,extra={})=>({type:'WNOTE_FIRE',t:'2',start:'0',end:'2',sampling_valid:'true',owner:'10',life:'1',gun:'mp_weapon_rspn101',mods:'bt7274_solo_reload',config:'false:true:false:true:true',rounds:String(rounds),ads_rounds:String(ads),zoom_known:'true',reloads:'0',reason:'interval',...extra});
  const r=analyzeNotes([...clean(),fire(10,6),fire(6,0,{start:'2',end:'3'}),fire(5,5,{mods:'other'})]);
  const main=r.accuracy.find(g=>g.mods==='bt7274_solo_reload');
  assert.equal(main.rounds,16);assert.equal(main.pilot_hits,4);assert.equal(main.pilot_hit_fraction,null);assert.equal(main.pilot_hits_per_observed_round,0.25);assert.equal(main.ads_fraction,6/16);
  assert.equal(r.accuracy.find(g=>g.mods==='other').pilot_hits,0);
  const shotgun=analyzeNotes([ctx,fire(4,0,{gun:'mp_weapon_shotgun'})]).accuracy[0];assert.equal(shotgun.pilot_hit_fraction,null);
  const unknownZoom=analyzeNotes([ctx,fire(4,0,{zoom_known:'false'})]).accuracy[0];assert.equal(unknownZoom.ads_fraction,null);
  const other=analyzeNotes([{...ctx,map:'mp_glitch'},fire(4,0),...clean()]);assert.equal(other.accuracy[0].map,'mp_glitch');assert.equal(other.accuracy[0].pilot_hits,0);
  assert.equal(analyzeNotes([ctx,{type:'WNOTE_FIRE_ERROR',count:'1'}]).fire_errors,1);
  assert.equal(r.logger_errors,0);
});
test('view-kick bursts summarize per gun, modifier and ADS state',()=>{
  const kick=(dp,ads='true',mods='m')=>({type:'WNOTE_KICK',gun:'mp_weapon_vinson',mods,config:'c',ads,rounds:'10',dpitch:String(dp),dyaw:'0.5',max_dpitch:String(Math.abs(dp)),max_dyaw:'0.5',duration:'1'});
  const r=analyzeNotes([ctx,kick(-4),kick(-6),kick(-8,'false'),kick(-2,'true','m,solo_role_balance_v1')]);
  const ads=r.viewkick.find(g=>g.ads&&g.mods==='m');assert.equal(ads.bursts,2);assert.ok(Math.abs(ads.median_abs_dpitch_per_round-0.5)<1e-9);
  assert.equal(r.viewkick.length,3);
});

test('expenditure excludes untracked intervals, wrong actors/lives and invalid denominators',()=>{
  const f={type:'WNOTE_FIRE',owner:'10',life:'1',gun:'mp_weapon_rspn101',mods:'bt7274_solo_reload',config:'false:true:false:true:true',start:'1.05',end:'1.35',sampling_valid:'true',rounds:'10',ads_rounds:'0',reloads:'0'};
  const a=[...clean(),f,...hit(5,1.2,100,75,{attacker:'11'}),...hit(6,1.2,100,75,{attacker_life:'2'})];
  const g=analyzeNotes(a).accuracy[0];assert.equal(g.pilot_hits,3);assert.equal(g.pilot_hit_fraction,null);assert.equal(g.pilot_hits_per_observed_round,0.3);
  for(const extra of [{rounds:'1'},{sampling_valid:'false'},{start:undefined},{end:'0'},{rounds:'-2'}]){
    const row=analyzeNotes([...clean(),{...f,...extra}]).accuracy[0];
    assert.equal(row.pilot_hits_per_observed_round,null);
  }
  assert.equal(analyzeNotes([...clean(),f,{...f}]).accuracy[0].sampling_valid,false);
});
test('expenditure preserves config boundaries instead of borrowing hits from another config',()=>{
  const f={type:'WNOTE_FIRE',owner:'10',life:'1',gun:'mp_weapon_rspn101',mods:'bt7274_solo_reload',config:'new',start:'0',end:'2',sampling_valid:'true',rounds:'4',ads_rounds:'0'};
  assert.equal(analyzeNotes([...clean(),f]).accuracy[0].pilot_hits,0);
});
