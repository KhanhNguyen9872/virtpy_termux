sig = __import__('signal').SIGTERM
kill = __import__('os').kill
sleep = __import__('time').sleep

def maxmem(pid: int, mem: int):
    if int(mem) < 0:
        return
    sleep(0.5)
    process = __import__('psutil').Process(pid)
    memory = int(process.memory_info().rss / 1024 / 1024)
    if memory == 0:
        print("\nCANNOT GET MEMORY USAGE, STOPPING LIMIT FEATURE")
        return
    while True:
        memory = int(process.memory_info().rss / 1024 / 1024)
        if memory == 0:
            return
        if memory > mem:
            kill(pid, sig)
            print("\nKILLED because limit exceeded (cur = {} MB) (max = {} MB)".format(memory, mem))
            return
        sleep(1)
    return

args = __import__('sys').argv
executable = args[1]
max_mem = args[2]
args = args[3:]

p = __import__('subprocess').Popen([executable, *args])
maxmem(p.pid, int(max_mem))
p.wait()
__import__('sys').exit(0)
