<div align="center">


<h1> <code>⚙️ Make.sh</code><br>A Tiny, Portable, Drop-in Alternative to GNU Make</h1>

__💡 100% POSIX Shell — No Compilers. No Dependencies. Just Build.__


[![Test](https://github.com/ko1nksm/getoptions/workflows/Test/badge.svg)](https://github.com/ko1nksm/getoptions/actions)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/ko1nksm/getoptions?logo=codefactor)](https://www.codefactor.io/repository/github/ko1nksm/getoptions)
[![Codecov](https://img.shields.io/codecov/c/github/ko1nksm/getoptions?logo=codecov)](https://codecov.io/gh/ko1nksm/getoptions)
[![kcov](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fko1nksm.github.io%2Fgetoptions%2Fcoverage.json&query=percent_covered&label=kcov&suffix=%25)](https://ko1nksm.github.io/getoptions/)
[![GitHub top language](https://img.shields.io/github/languages/top/ko1nksm/getoptions.svg)](https://github.com/ko1nksm/getoptions/search?l=Shell)
[![License](https://img.shields.io/github/license/francescobianco/make.sh.svg)](https://github.com/francescobianco/make.sh/blob/main/LICENSE)<br>
![Linux](https://img.shields.io/badge/Linux-ecd53f?style=flat)
![macOS](https://img.shields.io/badge/macOS-ecd53f?style=flat)
![BSD](https://img.shields.io/badge/BSD-ecd53f?style=flat)
![Solaris](https://img.shields.io/badge/Solaris-ecd53f?style=flat)
![AIX](https://img.shields.io/badge/AIX-ecd53f?style=flat)
![BusyBox](https://img.shields.io/badge/BusyBox-ecd53f?style=flat)
![Windows](https://img.shields.io/badge/Windows-ecd53f?style=flat)
![sh](https://img.shields.io/badge/sh-cec7d1.svg?style=flat)
![bash](https://img.shields.io/badge/bash-cec7d1.svg?style=flat)
![dash](https://img.shields.io/badge/dash-cec7d1.svg?style=flat)
![ksh](https://img.shields.io/badge/ksh-cec7d1.svg?style=flat)
![mksh](https://img.shields.io/badge/mksh-cec7d1.svg?style=flat)
![yash](https://img.shields.io/badge/yash-cec7d1.svg?style=flat)
![zsh](https://img.shields.io/badge/zsh-cec7d1.svg?style=flat)



</div>

## 🚀 What is `make.sh`?

**Make.sh is a POSIX-compliant, shell-based alternative to GNU Make** — designed to run standard Makefiles **without installing any build tools or system packages**.

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

## 📦 Install it from the CDN

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

## 👏 Acknowledgements

I would like to express my sincere gratitude to those who have contributed to maintaining the idea that Bash and all shell languages are proper programming languages, deserving to be treated with the appropriate tools.

Special thanks to:

**Joseph Werle** (@jwerle) and **Ben Peachey** (@Potherca) for their outstanding work in maintaining BPKG and for their contribution in supporting the Bash ecosystem, demonstrating that shell languages deserve the same dignity as other programming languages.

A special acknowledgement goes to **Koichi Nakashima** (@ko1nksm), not only for his pioneering work on ShellSpec, but also for his determination and willingness to keep the world of shell languages at the cutting edge. His vision has shown that these languages are full of possibilities and without effective limitations.

Thanks to their commitment, the shell languages community continues to thrive and evolve, providing developers with powerful and elegant tools to solve complex problems.

## 👨‍💻 Maintainer

Created with 🍝 by [Francesco Bianco](https://github.com/francescobianco)

> `make.sh` — When **Make** meets **Minimalism**.
