vcl 4.1;
import tinykvm;

backend default none;

sub vcl_init {
	# Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
	tinykvm.init_self_requests("/tmp/tinykvm.sock");

	tinykvm.configure("hello_world_rust_gnu",
		"""{
			"filename": "/hello_world_rust_gnu"
		}""");
	tinykvm.configure("hello_world_rust_musl",
		"""{
			"filename": "/hello_world_rust_musl"
		}""");
}

sub vcl_recv {
	return(pass);
}

sub vcl_backend_fetch {
	if (bereq.url == "/hello_world_rust_gnu") {
		set bereq.backend = tinykvm.program("hello_world_rust_gnu", bereq.url);
	} else if (bereq.url == "/hello_world_rust_musl") {
		set bereq.backend = tinykvm.program("hello_world_rust_musl", bereq.url);
	} else {
		return(error(404, "Not found"));
	}
}
