# Build Script

ARCH SUPPORTED:

1. riscv64
2. aarch64

### Run sel4-test

```shell
make ARCH=riscv64 sel4-test
```
#### Run sel4-test with MCS feature
```shell
make ARCH=aarch64 MCS=on sel4-test
```

### Run root-task-demo

```shell
make ARCH=riscv64 root-task-demo
```

Enjoy it 😆!
