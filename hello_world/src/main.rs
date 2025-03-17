#[allow(dead_code)]
mod varnish;

fn on_get(_url: &str, _arg: &str) -> ! {
    varnish::backend_response_str(200, "text/plain", "Hello Rusty Compute World!");
}

fn is_sandboxed_main() -> bool {
    ::std::env::args_os().next().is_some_and(|x| {
        x.into_encoded_bytes()
            .iter()
            .find(|&&c| c == b'/')
            .is_none()
    })
}

fn main() {
    if !is_sandboxed_main() {
        println!("Hello Rusty Linux World!");
        return;
    }
    varnish::set_backend_get(on_get);
    varnish::wait_for_requests();
}
