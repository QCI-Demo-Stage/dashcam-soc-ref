/* Minimal CRT entry for bare-metal firmware builds. */
extern int main(void);

void _start(void) {
    (void)main();
    for (;;) {
    }
}
