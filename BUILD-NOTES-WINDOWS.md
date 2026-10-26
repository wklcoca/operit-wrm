# 在 Windows 上构建 Operit2（我们踩过的坑）

> 这是 2056 构建时用的实际环境记录。上游有自己的构建文档，这里只写**在 Windows 上照上游文档做会失败的地方**。

## 工具链

| 组件 | 版本 / 位置 |
|---|---|
| JDK | Temurin 17（`JAVA_HOME`） |
| Gradle | 8.11.1 |
| Android SDK | platforms 34/35/36、build-tools 34/35/36、**NDK 29.0.14206865** |
| Flutter | OHOS fork `3.41.10-ohos-0.0.2-beta.operit.3`，junction 进 `apps/flutter/app/.fvm/flutter_sdk` |
| Rust | 1.99.1 + `aarch64-linux-android` target |
| Node / pnpm | 18.x + pnpm 10（`CI=true` 避免交互式 purge） |
| Python | 3.12（构建脚本用） |

## 九个必须做的调整

1. **Flutter SDK 需要是 git 仓库**：建一个最小 repo、打上对应 tag，且 `bin/internal/engine.version`、`engine.ohos.version` 必须被 track ——
   `update_engine_version.ps1` 用 `git ls-files` 读它们，未 track 会得到空 engine stamp。
2. **Dart SDK** 来自 fork 的 Huawei OBS 地址，`bin/cache` 要在 Windows 上重建。
3. **Gradle wrapper 的下载地址**从 `services.gradle.org` 换成镜像（否则超时）。
4. **Gradle init script 只在 settings 层加镜像**：本项目用 `PREFER_SETTINGS`，在 project 层加仓库会导致解析失败。
5. **pnpm**：corepack 无法校验 npmmirror 签名，用一个 shim 转发到全局 pnpm。
6. **bindgen 需要宿主 libclang**：把 `OPERIT_LIBCLANG_DIR` 指向 NDK 的 `windows-x86_64/bin`，
   并让该目录在 `PATH` 上（否则 `libxml2.dll` / `libwinpthread-1.dll` 加载失败）。
7. **`.venv`** 要重建为真实 venv（`pyvenv.cfg` + `Lib` junction）。
8. `app/hook/build.dart` 认 `OPERIT_PYTHON`，宿主 Python 通过它传进去。
9. **不要用 `--enforce-lockfile`**：仓库里的 `pubspec.lock` 是在设备上产生的，和 Windows 上解析出的图不同。

## 构建命令

```powershell
# 环境变量（JAVA_HOME / ANDROID_HOME / GRADLE_USER_HOME / OPERIT_LIBCLANG_DIR / PATH …）
. <你的路径>\build_env.ps1

cd <repo>\tools\build_scripts
python build_flutter_android.py --build-name 2.0.0 --build-number 56
```

`versionCode = 2000 + build-number`。产物落在
`tools/release/dist/operit2-app-android-arm64-v8a-<versionName>-preview.<n>.apk`

> 注意：**dist 里的文件名不含 build number**，别靠文件名判断版本 —— 用
> `aapt2 dump badging <apk> | Select-String versionCode` 核对。

## 签名

构建脚本用自己的 keystore 签名（`tools/release/secrets/`，本地文件、不入库）。
我们用的证书 SHA-256 是 `c15a0e57c2a54463026ee6479dad86a9bef6985d4ee4b063390daa261b5bbe41`，
**与官方包不同**，所以不能覆盖安装官方版。

## 验证产物

```powershell
aapt2 dump badging <apk> | Select-String versionCode
apksigner verify --print-certs <apk>
```

Rust 逻辑的修复大多没有可 grep 的唯一字符串；可靠的验证方式是
**对该踏改动的 crate 跑对应单测**（例如 `cargo test -p operit-tools --lib`），
而不是只 grep `.so`。
