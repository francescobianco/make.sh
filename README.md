# ⚙️ make.sh — A Tiny, Portable, Drop-in Alternative to GNU Make  

> 💡 100% POSIX Shell — No Compilers. No Dependencies. Just Build.

## 🚀 What is `make.sh`?

**`make.sh` is a POSIX-compliant, shell-based alternative to GNU Make** — designed to run standard Makefiles **without installing any build tools or system packages**.

It's ideal for:

- Minimal Linux distributions (Alpine, BusyBox, etc.)
- Immutable systems (Fedora Silverblue, NixOS, Vanilla OS, etc.)
- Clean, dependency-free Docker containers
- macOS environments without Xcode
- CI/CD pipelines using ultra-slim base images

## 🔍 Why use make.sh? — Real World Use Cases

### 🧊 **Immutable Linux distributions**
On distros like **Fedora Silverblue**, **Vanilla OS**, or **NixOS**, the root filesystem is read-only and tools like `make` are not installed by default. `make.sh` runs directly in `/bin/sh`, without breaking immutability or layering hacks.

### 🐧 **Minimal Linux systems**
On lightweight environments like **Alpine**, **BusyBox**, or **embedded systems**, you often don’t have `make` pre-installed — and you don’t want to install toolchains just to run a Makefile. `make.sh` keeps it simple.

### 🍏 **On macOS and tired of installing half of GNU?**
Installing GNU Make on macOS often pulls in Homebrew, Xcode CLT, and compatibility patches. Why bother? Just drop in `make.sh`.

### 🐳 **Containers should be lean**
Avoid bloated containers and redundant multi-stage builds. Just add `make.sh` and skip installing dev packages entirely.

### 🔄 **CI/CD pipelines with minimal images**
Slim CI runners (like Alpine or Debian-slim) don’t include `make`. Installing it costs time and bandwidth. `make.sh` is a one-liner download.

## 🧱 ASCII Art Break

> Because shell scripts deserve style too 🧢

```
  __  __      _            _    
 |  \/  |__ _| |_____   __| |_  
 | |\/| / _` | / / -_)_(_-< ' \ 
 |_|  |_\__,_|_\_\___(_)__/_||_|
                                
        Lightweight Make
        Written in Shell
```

## ✨ Features

- ✅ Pure POSIX shell — no runtime or compiler required
- ✅ Works with standard Makefile syntax
- ✅ Single file — easy to bundle or serve from CDN
- ✅ Compatible with Linux, macOS, CI/CD, Docker, WSL
- ✅ Ideal for immutable and minimal environments

## ⚡️ Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/francescobianco/make.sh/main/bin/make.sh -o make.sh
chmod +x make.sh
./make.sh target
```

## 📦 Install it from a CDN

```bash
curl -fsSL https://get.javanile.org/make.sh | sh -
```

## 🧪 Example Makefile

```makefile
build:
	echo "Compiling..."
	touch build/output.bin

clean:
	rm -rf build
```

Run it:

```bash
./make.sh build
./make.sh clean
```

## 📌 Compatibility

- ✅ Targets and recipes
- ✅ Variables and dependencies
- ❌ No advanced GNU Make functions (wildcards, conditionals, pattern rules)

`make.sh` is designed for simplicity and portability — not for replacing every GNU Make feature.

## 🔐 License

MIT — see [LICENSE](LICENSE)

## 🤝 Contribute

Feel free to fork, open issues, or send pull requests.  
Improvements, bug fixes, and creative use cases are all welcome!

## 👨‍💻 Maintainer

Created with 🍝 by [Francesco Bianco](https://github.com/francescobianco)

> `make.sh` — When **Make** meets **Minimalism**.
