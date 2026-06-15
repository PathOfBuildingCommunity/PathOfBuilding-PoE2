#include "Host.hpp"

int main(int argc, char** argv) {
    Host host;
    if (!host.init(argc, argv)) {
        return 1;
    }
    return host.run();
}

