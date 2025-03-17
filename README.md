# Fixed ~~Error~~ using static glibc builds with Varnish TinyKVM

> [!NOTE]  
> This was fixed by varnish/tinykvm#20

Reproducer to demonstrate broken static glibc Rust builds with Varnish TinyKVM.

The current examples of Rust with Varnish TinyKVM use musl.
I'd like the option to use glibc for software that is difficult to build with musl.

Note I have successfully built and run the hello_world.c example against glibc statically with both gcc and clang and verified it works with Varnish TinyKVM.

    gcc -O2 -Wall -static hello_world.c -o hellogcc
    clang -O2 -Wall -static hello_world.c -o helloclang

[Building static Rust binaries for Linux](https://msfjarvis.dev/posts/building-static-rust-binaries-for-linux/) has instructions for building rust programs statically against glibc.

    RUSTFLAGS='-C target-feature=+crt-static' cargo build --release --target x86_64-unknown-linux-gnu

I can build a static binary with these flags and run it in Linux but it does not work under TinyKVM where it errors with `Invalid ELF type: Not an executable!`.

```
[3/4] STEP 6/6: RUN set -e;     export RUSTFLAGS='-C target-feature=+crt-static';     cargo build --release --target x86_64-unknown-linux-gnu;     ldd /hello_world/target/x86_64-unknown-linux-gnu/release/hello_world;     /hello_world/target/x86_64-unknown-linux-gnu/release/hello_world
   Compiling hello_world v0.1.0 (/hello_world)
    Finished `release` profile [optimized] target(s) in 1.79s
        statically linked
Hello Rusty Linux World!
```

The examples using musl have a different set of flags. These work for me both on Linux and in the TinyKVM.

```
[3/4] STEP 5/6: RUN set -e;     export RUSTFLAGS='-C link-args=-Wl,-Ttext-segment=0x400000';     cargo build --release --target x86_64-unknown-linux-musl;     ldd /hello_world/target/x86_64-unknown-linux-musl/release/hello_world;     /hello_world/target/x86_64-unknown-linux-musl/release/hello_world
   Compiling hello_world v0.1.0 (/hello_world)
    Finished `release` profile [optimized] target(s) in 1.80s
        statically linked
Hello Rusty Linux World!
```

However if I add these to the static glibc RUSTFLAGS I get a segmentation fault under linux.

```
[3/4] STEP 6/6: RUN set -e;     export RUSTFLAGS='-C target-feature=+crt-static -C link-args=-Wl,-Ttext-segment=0x400000';     cargo build --release --target x86_64-unknown-linux-gnu;     ldd /hello_world/target/x86_64-unknown-linux-gnu/release/hello_world;     /hello_world/target/x86_64-unknown-linux-gnu/release/hello_world
   Compiling hello_world v0.1.0 (/hello_world)
    Finished `release` profile [optimized] target(s) in 1.78s
        statically linked
Segmentation fault (core dumped)
```

## Steps to reproduce

I've been using podman but this should also work under docker.
I installed the static version of podman from https://github.com/mgoltzsche/podman-static on Ubuntu 24.04 and followed the apparmor profile instructions.

Build 

    podman build -t varnish-tinykvm .

Then run concurrently:

    podman run --rm -p 127.0.0.1:8080:8080 -e VARNISH_HTTP_PORT=8080 --device /dev/kvm --group-add keep-groups --name varnish-tinykvm varnish-tinykvm
    podman exec -it varnish-tinykvm varnishlog
    curl http://localhost:8080/hello_world_rust_gnu
    curl http://localhost:8080/hello_world_rust_musl

## Error from varnishlog

Failed request for /hello_world_rust_gnu.

```
*   << BeReq    >> 3         
-   Begin          bereq 2 pass
-   VCL_use        boot
-   Timestamp      Start: 1742193065.134427 0.000000 0.000000
-   BereqMethod    GET
-   BereqURL       /hello_world_rust_gnu
-   BereqProtocol  HTTP/1.1
-   BereqHeader    Host: localhost:8080
-   BereqHeader    User-Agent: curl/8.5.0
-   BereqHeader    Accept: */*
-   BereqHeader    X-Forwarded-For: 192.168.50.20
-   BereqHeader    Via: 1.1 47c3afc4a959 (Varnish/7.6)
-   BereqHeader    X-Varnish: 3
-   VCL_call       BACKEND_FETCH
-   VCL_return     fetch
-   Timestamp      Fetch: 1742193065.134627 0.000200 0.000200
-   Error          VM 'hello_world_rust_gnu' exception: Invalid ELF type: Not an executable!
-   Error          KVM: Unable to reserve VM for index 0, program hello_world_rust_gnu
-   Timestamp      Beresp: 1742193065.139595 0.005167 0.004967
-   Timestamp      Error: 1742193065.139600 0.005173 0.000005
-   BerespProtocol HTTP/1.1
-   BerespStatus   503
-   BerespReason   Backend fetch failed
-   BerespHeader   Date: Mon, 17 Mar 2025 06:31:05 GMT
-   BerespHeader   Server: Varnish
-   VCL_call       BACKEND_ERROR
-   BerespHeader   Content-Type: text/html; charset=utf-8
-   BerespHeader   Retry-After: 5
-   VCL_return     deliver
-   Storage        malloc Transient
-   Length         278
-   BereqAcct      0 0 0 0 0 0
-   End            
```

Working request for /hello_world_rust_musl.

```
*   << BeReq    >> 6         
-   Begin          bereq 5 pass
-   VCL_use        boot
-   Timestamp      Start: 1742193110.553021 0.000000 0.000000
-   BereqMethod    GET
-   BereqURL       /hello_world_rust_musl
-   BereqProtocol  HTTP/1.1
-   BereqHeader    Host: localhost:8080
-   BereqHeader    User-Agent: curl/8.5.0
-   BereqHeader    Accept: */*
-   BereqHeader    X-Forwarded-For: 192.168.50.20
-   BereqHeader    Via: 1.1 47c3afc4a959 (Varnish/7.6)
-   BereqHeader    X-Varnish: 6
-   VCL_call       BACKEND_FETCH
-   VCL_return     fetch
-   Timestamp      Fetch: 1742193110.553053 0.000031 0.000031
-   VCL_Log        hello_world_rust_musl: Calling on_get() at 0x405FC0
-   BerespHeader   Content-Type: text/plain
-   BerespProtocol HTTP/1.1
-   BerespStatus   200
-   BerespReason   OK
-   BerespHeader   Content-Length: 26
-   BerespHeader   Last-Modified: Mon, 17 Mar 2025 06:31:50 GMT
-   Timestamp      Beresp: 1742193110.559848 0.006827 0.006795
-   BerespHeader   Date: Mon, 17 Mar 2025 06:31:50 GMT
-   VCL_call       BACKEND_RESPONSE
-   VCL_return     deliver
-   Timestamp      Process: 1742193110.559856 0.006834 0.000007
-   Filters        
-   Storage        malloc Transient
-   Fetch_Body     3 length stream
-   Timestamp      BerespBody: 1742193110.559894 0.006873 0.000038
-   Length         26
-   BereqAcct      0 0 0 0 26 26
-   End            
```
