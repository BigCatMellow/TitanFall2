//! A bounded local game-persistence snapshot, bound to owner and PDEF schema.
use std::{fs, io::{self, Write}, path::Path};
pub(super) const SIZE: usize = 0xddcd;
pub(super) fn fingerprint(bytes: &[u8]) -> u64 {
    bytes.iter().fold(14695981039346656037, |hash, b| (hash ^ *b as u64).wrapping_mul(1099511628211))
}
pub(super) fn valid_owner(owner: &str) -> bool {
    !owner.is_empty() && owner.len() <= 31 && owner != "0" && owner.bytes().all(|c| c.is_ascii_digit())
}
pub(super) fn encode(owner: &str, schema: u64, payload: &[u8]) -> Result<Vec<u8>, &'static str> {
    if !valid_owner(owner) || payload.len() != SIZE { return Err("invalid owner or payload size"); }
    let mut out = b"JLPDATA1".to_vec();
    out.extend(schema.to_le_bytes()); out.extend(fingerprint(payload).to_le_bytes());
    out.push(owner.len() as u8); out.extend(owner.as_bytes());
    out.extend((payload.len() as u32).to_le_bytes()); out.extend(payload);
    Ok(out)
}
pub(super) fn decode<'a>(file: &'a [u8], owner: &str, schema: u64) -> Result<&'a [u8], &'static str> {
    if file.len() < 29 || &file[..8] != b"JLPDATA1" { return Err("invalid snapshot header"); }
    let stored_schema = u64::from_le_bytes(file[8..16].try_into().map_err(|_| "schema header")?);
    let checksum = u64::from_le_bytes(file[16..24].try_into().map_err(|_| "checksum header")?);
    let uid_len = file[24] as usize;
    if uid_len == 0 || uid_len > 31 || file.len() < 29 + uid_len { return Err("invalid owner header"); }
    let uid = std::str::from_utf8(&file[25..25+uid_len]).map_err(|_| "invalid owner encoding")?;
    if !valid_owner(uid) || uid != owner { return Err("snapshot belongs to another player"); }
    if stored_schema != schema { return Err("persistence schema changed; snapshot preserved without loading"); }
    let len = u32::from_le_bytes(file[25+uid_len..29+uid_len].try_into().map_err(|_| "length header")?) as usize;
    let payload = &file[29+uid_len..];
    if len != SIZE || payload.len() != SIZE { return Err("invalid snapshot length"); }
    if fingerprint(payload) != checksum { return Err("snapshot checksum mismatch"); }
    Ok(payload)
}
pub(super) fn atomic_write(path: &Path, bytes: &[u8]) -> io::Result<()> {
    if let Some(parent) = path.parent() { fs::create_dir_all(parent)?; }
    let temporary = path.with_extension("pending");
    let mut file = fs::File::create(&temporary)?;
    file.write_all(bytes)?; file.sync_all()?; drop(file);
    if path.exists() { fs::copy(path, path.with_extension("bak"))?; }
    fs::rename(temporary, path)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn roundtrip_preserves_all_bytes_and_rejects_other_owners_or_schemas() {
        let payload: Vec<_>=(0..SIZE).map(|i| (i % 251) as u8).collect();
        let file=encode("12345",77,&payload).unwrap();
        assert_eq!(decode(&file,"12345",77).unwrap(), payload);
        assert!(decode(&file,"54321",77).is_err());
        assert!(decode(&file,"12345",78).is_err());
    }
    #[test]
    fn corrupt_truncated_and_wrong_sized_data_are_rejected() {
        let mut file=encode("12345",77,&vec![42;SIZE]).unwrap();
        assert!(decode(&file[..file.len()-1],"12345",77).is_err());
        file[100]^=1; assert!(decode(&file,"12345",77).is_err());
        assert!(encode("0",77,&vec![0;SIZE]).is_err());
        assert!(encode("../bad",77,&vec![0;SIZE]).is_err());
        assert!(encode("12345",77,&[0;8]).is_err());
    }
    #[test]
    fn replacing_a_snapshot_retains_a_previous_backup() {
        let root=std::env::temp_dir().join(format!("bt7274-presets-{}",std::process::id()));
        let path=root.join("12345.bin");
        atomic_write(&path,b"first").unwrap(); atomic_write(&path,b"second").unwrap();
        assert_eq!(fs::read(&path).unwrap(),b"second");
        assert_eq!(fs::read(path.with_extension("bak")).unwrap(),b"first");
    }
    #[test]
    fn live_readonly_backup_is_compatible_when_fixture_is_supplied() {
        let Ok(path)=std::env::var("LOCAL_PRESET_FIXTURE") else { return; };
        let file=fs::read(path).unwrap();
        let len=file[24] as usize;
        let owner=std::str::from_utf8(&file[25..25+len]).unwrap();
        let schema=u64::from_le_bytes(file[8..16].try_into().unwrap());
        assert_eq!(decode(&file,owner,schema).unwrap().len(),SIZE);
    }
}
