use anyhow::Result;
use flutter_rust_bridge as frb;

pub use awasmlib::prelude::*;

#[frb::frb(init)]
pub fn init_app() {
    frb::setup_default_user_utils();
}

#[frb::frb]
pub async fn new_handle() -> Result<Handle> {
    Ok(Handle::new().await?)
}
