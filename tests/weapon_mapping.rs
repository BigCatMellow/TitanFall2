//! Offline consistency checks; these do not replace a Northstar runtime test.
const SCRIPT: &str = include_str!("../James.WeaponReload/mod/scripts/vscripts/james_weapon_reload.nut");
const MOD_JSON: &str = include_str!("../James.WeaponReload/mod.json");

const WEAPONS: [(&str, &str); 5] = [
    ("mp_weapon_g2", include_str!("../James.WeaponReload/keyvalues/scripts/weapons/mp_weapon_g2.txt")),
    ("mp_weapon_alternator_smg", include_str!("../James.WeaponReload/keyvalues/scripts/weapons/mp_weapon_alternator_smg.txt")),
    ("mp_weapon_hemlok_smg", include_str!("../James.WeaponReload/keyvalues/scripts/weapons/mp_weapon_hemlok_smg.txt")),
    ("mp_weapon_rspn101", include_str!("../James.WeaponReload/keyvalues/scripts/weapons/mp_weapon_rspn101.txt")),
    ("mp_weapon_car", include_str!("../James.WeaponReload/keyvalues/scripts/weapons/mp_weapon_car.txt")),
];

#[test]
fn supported_class_names_match_weapon_overrides() {
    let list = SCRIPT.split("array<string> supported = [").nth(1).expect("supported array");
    let list = list.split(']').next().expect("supported array terminator");
    let mut actual: Vec<_> = list.split('"').skip(1).step_by(2).collect();
    let mut expected: Vec<_> = WEAPONS.iter().map(|(name, _)| *name).collect();
    actual.sort_unstable();
    expected.sort_unstable();
    assert_eq!(actual, expected, "each supported class needs exactly one override");
    assert!(actual.contains(&"mp_weapon_alternator_smg"), "Alternator is not the Volt");
    assert!(actual.contains(&"mp_weapon_hemlok_smg"), "preserve the existing Volt buff");
}

#[test]
fn each_weapon_override_scales_all_reload_checkpoints() {
    for (name, kv) in WEAPONS {
        assert!(kv.contains("james_solo_reload"), "missing mod definition: {name}");
        for field in [
            "reload_time", "reload_time_late1", "reload_time_late2", "reload_time_late3",
            "reloadempty_time", "reloadempty_time_late1", "reloadempty_time_late2",
            "reloadempty_time_late3",
        ] {
            assert!(kv.contains(&format!("{field} \"*0.9\"")), "{name}: {field}");
        }
    }
}

#[test]
fn manifest_identifies_both_smgs() {
    assert!(MOD_JSON.contains("Alternator, Volt"));
    assert!(MOD_JSON.contains("\"Version\": \"1.0.1\""));
}
