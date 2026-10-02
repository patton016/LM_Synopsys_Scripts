# Synopsys 芯片设计软件自动化安装 / 启动 / License 校验脚本

依据《【老刘炼芯】十款Synopsys芯片设计软件的部署》一文编写。
环境基线：AlmaLinux 8.10；Installer 5.9、SCL 2025.03、其余软件包 2023.12。
**跨发行版支持**：同一套脚本可在 AlmaLinux 8 / CentOS 7 / Ubuntu 18.04+ 上运行，
包管理器（dnf / yum / apt-get）自动探测，Ubuntu 的包名差异自动映射（见 `common.sh`）。

## 快速开始

**运行身份**：安装/卸载请用**普通用户**直接运行（勿加 `sudo`）——Synopsys Installer
拒绝 root 账户（"The Installer must not be run from a root user account"），root 下
安装向导会直接退出。需要 root 的步骤（安装 tcsh/依赖库、License 部署的
systemd/SELinux 等）脚本会自动 `sudo` 提权，届时按提示输入密码即可。

```bash
# 1) 复制配置模板并按需设置安装开关与路径
cp install.conf.example install.conf
vim install.conf

# 2) 只安装 VCS 和 Verdi
bash install_all.sh --only vcs,verdi

# 3) 全部安装（License 部署步会自动 sudo）
bash install_all.sh --all

# 4) 交互式勾选安装
bash install_all.sh --interactive

# 5) 只做 License 部署与校验（部署需要 root，直接 sudo 运行）
sudo bash license/setup_license.sh
bash license/check_license.sh

# 6) 卸载全部软件（逐项确认；License 卸载步会自动 sudo）
bash uninstall_all.sh

# 7) 只卸载 VCS 和 Verdi（--force 跳过逐项确认）
bash uninstall_all.sh --only vcs,verdi --force

# 8) 卸载时保留 License 认证
bash uninstall_all.sh --skip-license

# 9) 只安装软件，不部署/校验 License（License 之后想部署时再单独跑 setup_license.sh）
bash install_all.sh --all --skip-license

# 10) 运行前清空 run.log（默认追加保留历史；加 --clean-log 则只保留本次运行记录）
bash install_all.sh --all --clean-log

# 11) License 认证完成后，统一启动验证（文中 3.1~3.10 节；含 VCS smoke 用例）
bash verify_all.sh
```

## 目录结构

```
LM_Synopsys_Scripts/install/
├── README.md                本说明
├── CHANGELOG.md             版本记录（Keep a Changelog 格式）
├── common.sh                公共函数库（日志 / Installer 命令行自动应答 / bashrc 注入 / 依赖库 / 结果汇总）
├── install.conf.example     顶层配置模板（复制为 install.conf 后按需修改；install.conf 已被 .gitignore 排除）
├── install_all.sh           顶层入口：按配置安装 Installer + SCL + 选中的软件 + License 部署
├── uninstall_all.sh         顶层入口：卸载软件（--only / --interactive / --force）
├── verify_all.sh            顶层入口：License 认证后统一启动验证（文中 3.x 节）
├── tools/
│   ├── install_installer.sh  Installer 5.9
│   ├── install_scl.sh        SCL 2025.03（License 许可工具）
│   ├── install_vcs.sh        VCS
│   ├── install_verdi.sh      Verdi
│   ├── install_spyglass.sh   Spyglass（含 Docs 文档包自动安装）
│   ├── install_dc.sh         Design Compiler
│   ├── install_formality.sh  Formality
│   ├── install_fc.sh         Fusion Compiler
│   ├── install_icc2.sh       ICC2（含依赖库自动补齐）
│   ├── install_pt.sh         PrimeTime（含 DGCOM_ROOT）
│   ├── install_lc.sh         Library Compiler
│   ├── install_hspice.sh     Hspice
│   └── uninstall_*.sh        与 install_*.sh 一一对应的卸载脚本（删 bashrc 块 + 删安装目录）
├── license/
│   ├── setup_license.sh      License 认证部署（拷贝 .dat / LSB / systemd / SELinux）
│   ├── uninstall_license.sh  License 认证卸载（停服务 / 删文件 / 清 SELinux 规则）
│   ├── start_license.sh      License 服务启停脚本（文中 2.2.1 版参数化）
│   ├── check_license.sh      License 校验（lmstat / 进程 / 特性核对）
│   └── snps-license.service  systemd 服务单元模板（文中 2.2.2 版参数化）
├── utils/
│   ├── diagnose_scl.sh       SCL 安装与 PATH 只读诊断（不改任何文件）
│   └── clean_old_config.sh   清理 ~/.bashrc 中旧版 Synopsys 配置（先备份、可还原）
└── verify/
    └── vcs_smoke/            VCS 启动验证工程（run_smoke.sh + 示例设计，产物拆分 work/ 与 result/）
```

## 重要说明（务必阅读）

1. **实测声明**：核心安装/卸载链路已在 **CentOS 7** 实测核验（`install_all.sh --skip-license --clean-log`、
   `uninstall_all.sh`）；AlmaLinux 8 / Ubuntu 18.04+ 为跨发行版适配目标，包管理器与包名差异已自动探测
   （见 `common.sh`），建议先在虚拟机/测试机完整跑一遍再用于正式部署。软件安装采用 Installer 5.9
   **命令行模式**（`-source` / `-target` 直传，Site ID 与交互应答由 stdin 管道喂入，无交互问答），
   安装异常时查看 `run.log` 最新 `[SESSION]` 段。
2. **无 expect 依赖**：软件安装与 Installer 自身安装均不依赖 expect，全部通过 stdin 管道自动应答。
3. **发行版差异**：除包管理外，仅 SELinux 一段有差异——Ubuntu 默认无 SELinux
   （AppArmor），`setup_license.sh` 检测到非 Enforcing 会自动跳过规则配置，无需改动；
   CentOS 7 的 SELinux 行为与 AlmaLinux 一致。若在 Ubuntu 24.04 安装 ICC2 依赖
   `libnsl` 失败，请将 `common.sh` 中 `apt-get:libnsl → libnsl1` 改为 `libnsl2`；
   32 位系统如遇 lmgrd 缺库，需另装 `libc6-i386`（Ubuntu）/ `glibc.i686`（RHEL 系）。
4. **路径**：`PKG_BASE` 为安装包存放目录（文中示例
   `/home/<user>/下载/AlmaLinux_ASIC/Synopsys/`），请按你的实际情况修改；
   `INSTALL_ROOT` 默认 `/home/<user>/usr/synopsys`（与 `install.conf.example` 一致；文中示例为
   `/mnt/asic/Software/Synopsys`，按你的实际环境修改）。
5. **License 文件**：《Synopsys.dat》需通过官方正规渠道或公司授权获得，脚本不会
   生成或下载 License 文件；部署前请放入本脚本目录下的 `license` 文件夹
   （`install/license/Synopsys.dat`），运行 `setup_license.sh` 时脚本会自动复制到
   `$INSTALL_ROOT/scl/$SCL_VERSION/admin/license/Synopsys.dat` 并部署启动。
   **注意：`license/Synopsys.dat` 为本地授权文件，已被 `.gitignore` 排除，请勿提交到仓库。**
6. **主机名一致性**：`HOSTNAME`、`SNPSLMD_LICENSE_FILE` 端口@主机名、License 文件
   中登记的 SERVER 主机名三者必须一致（文中 2.1 节），修改主机名后需重启或
   `hostnamectl set-hostname` 后重新登录。
7. **bashrc 注入**：每个软件脚本只注入自己的环境变量段（带 `# >>> SYNOPSYS:xxx`
   标记，幂等，重复执行不会叠加；内容一致时静默跳过）。环境变量写入**实际登录用户**
   （sudo 发起人，即 `SUDO_USER`）的 `~/.bashrc`，而非 root 的 `/root/.bashrc`；
   安装/卸载完成后脚本会自动 `source` 该 bashrc，无需手动执行。安装/卸载前还会
   **自动检测并清理 bashrc 中的旧版 Synopsys 配置**（如 2018 旧版块，先备份再注释，
   防止旧 PATH 干扰新版本）。SCL 的 PATH 不带 `/bin`（文中 1.3 差异点 2）、
   SPYGLASS_HOME 与 HSPICE_HOME 路径结构特殊（差异点 3、5），脚本已按文中处理。
8. **内存**：Synopsys 软件编译/跑大型设计非常吃内存（文中 3.4、总结），请按需配备。
9. **卸载安全**：卸载脚本默认逐项确认（`--force` 可跳过）；每个软件卸载 = 移除 bashrc
   对应环境变量块 + 删除 `$INSTALL_ROOT` 下安装目录（含附加目录与 Installer 状态目录
   `.installer` 的兜底清理）。License 文件（Synopsys.dat）为官方渠道获得的资产，
   `uninstall_license.sh` 删除前会单独确认，建议先备份；SCL 卸载前会自动停止
   snps-license 服务。`--skip-license` 可保留 License 认证。
10. **结果汇总与中断恢复**：安装/卸载完成（或被 Ctrl+C 中断）时，脚本都会输出结果汇总
    ——每款软件一行（状态 / 空间占用 / 安装用时），末尾统计**总空间占用**与**总用时**；
    Installer 由预装阶段处理，汇总中显示"已预装/已就绪"。`--skip-license` 时汇总标题为
    「结果汇总（已安装未认证）」。安装过程可随时 Ctrl+C 中断，已完成的软件不会重复安装
    （幂等跳过），重新运行 `install_all.sh` 即从未完成处继续。
11. **启动验证**：`verify_all.sh` 在 License 认证完成后统一执行文中 3.x 节各软件启动验证；
   其中 VCS 使用内置 smoke 工程（`verify/vcs_smoke`，编译 + 仿真生成 FSDB 波形，
   产物拆分 `work/` 过程文件与 `result/` 最终结果）。依赖库（tcsh 等）由 `pkg_install`
   自动安装（RHEL 系先 `rpm -q` 检查、已装即跳过，仅装缺失包；函数内部自动 sudo 提权）。
12. **运行日志**：所有脚本的 `[INFO] / [WARN] / [ERROR] / [ OK ]` 输出统一保存到
   本目录下的 **`run.log`**（追加写入、保留历史，每次运行带 `[SESSION]` 分隔头；
   Installer 的原始输出与报错也会实时写入 `run.log`，安装异常时从最新
   `[SESSION]` 段后直接查看向导原始信息）。如需清空旧日志，运行
   `install_all.sh` / `uninstall_all.sh` 时加 `--clean-log` 参数；也可用环境变量
   `LOG_PATH` 指定其他日志位置。Installer 5.9 强制生成的 `installer.log` 内容与
   `run.log` 重复，脚本运行后会**自动删除**，不会残留多余文件。License 服务的
   运行日志仍为 `$INSTALL_ROOT/scl/$SCL_VERSION/admin/logs/snps_license.log`
   （文中 2.2.1 节）。

## 许可

MIT License（见上级目录 `LICENSE`）。脚本仅提供自动化安装与运维能力，
**不包含、不生成任何破解、License 密钥或授权内容**；《Synopsys.dat》需通过官方
正规渠道或公司授权获得（本地文件已被 `.gitignore` 排除，请勿提交）。
