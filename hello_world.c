#include "kvm_api.h"
#include <string.h>
#include <stdio.h>

static void
on_get(const char *url, const char *arg)
{
	backend_response_str(200, "text/plain", "Hello Compute World!");
}

int main(int argc, char **argv)
{
	/* Macro to check if program is run from terminal. */ 
	if (IS_LINUX_MAIN()) {
		puts("Hello Linux World!");
		return 0;
	}

	set_backend_get(on_get);
	wait_for_requests();
}
