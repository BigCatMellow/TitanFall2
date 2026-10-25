use std::sync::atomic::{AtomicU32, Ordering};

static MAP_EPOCH: AtomicU32 = AtomicU32::new(0);
pub(super) fn begin_map() { MAP_EPOCH.fetch_add(1, Ordering::Relaxed); }
pub(super) fn epoch() -> u32 { MAP_EPOCH.load(Ordering::Relaxed) }

#[derive(Debug)]
pub(super) struct Metrics {
    pub target: Option<i32>,
    pub target_pos: [f32; 3],
    pub visible: bool,
    pub state: &'static str,
    pub switches: u32,
    pub recoveries: u32,
    pub path_failures: u32,
    pub path_requests: u32,
    pub jump_commands: u32,
    pub commands: u32,
    pub yaw_travel: f32,
    pub neighbors: usize,
    pub spacing_commands: u32,
    pub failed_goal_skips: u32,
    pub retreats: u32,
    last_yaw: Option<f32>,
}

impl Default for Metrics {
    fn default() -> Self { Self {
        target: None, target_pos: [0.; 3], visible: false, state: "idle",
        switches: 0, recoveries: 0, path_failures: 0, path_requests: 0,
        jump_commands: 0, commands: 0, yaw_travel: 0., neighbors: 0, spacing_commands: 0,
        failed_goal_skips: 0, retreats: 0, last_yaw: None,
    } }
}

impl Metrics {
    pub fn command(&mut self, yaw: f32, jump: bool) {
        self.commands = self.commands.saturating_add(1);
        self.jump_commands = self.jump_commands.saturating_add(jump as u32);
        if yaw.is_finite() {
            if let Some(last) = self.last_yaw {
                self.yaw_travel += ((yaw - last + 180.).rem_euclid(360.) - 180.).abs();
            }
            self.last_yaw = Some(yaw);
        }
    }
}
