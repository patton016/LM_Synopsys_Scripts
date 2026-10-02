# 老刘的 Synopsys ASIC 全栈开发脚本库（LM_Synopsys_Scripts）

微信公众号「老刘记事儿」· 官网 www.fpga.pw

> 随《老刘炼芯》系列文章持续更新的 ASIC 全栈开发脚本仓库：
> 从软件部署、License 运维，到数字前端设计、验证与后端，各阶段的可复用脚本按主题分目录存放。
> **`install/` 是第一个子项目（软件安装篇），后续将不断扩充。**

***

## 子项目一览

| 子项目 | 主题 | 配套文章 | 状态 |
| --- | --- | --- | --- |
| [install/](install/README.md) | Synopsys 十款软件安装 / 卸载 / License 部署与校验 / 启动验证 | 《【老刘炼芯】十款Synopsys芯片设计软件的部署》 | ✅ v1.0.0（CentOS 7 已实测） |
| … | 综合 / 验证 / 后端等脚本，陆续规划中 | — | 🚧 敬请期待 |

> 每个子项目独立维护自己的 `README.md`（含详细用法）、配置模板与 `.gitignore`，
> 相互解耦、可单独使用。

## 快速开始（以 install 为例）

```
cd LM_Synopsys_Scripts/install
cp install.conf.example install.conf
vim install.conf

# 全部安装（License 部署步自动 sudo 提权）
bash install_all.sh --all

# 只安装 VCS 和 Verdi（暂不部署 License）
bash install_all.sh --only vcs,verdi --skip-license

# License 一键部署与校验
sudo bash license/setup_license.sh
bash license/check_license.sh

# 统一启动验证（对应文中 3.1~3.10 节）
bash verify_all.sh

# 卸载全部（逐项确认；--force 跳过确认）
bash uninstall_all.sh
```

> 环境基线：AlmaLinux 8 / CentOS 7 / Ubuntu 18.04+；Installer 5.9、SCL 2025.03、其余软件包 2023.12。
> 完整命令选项、目录结构与注意事项见 [install/README.md](install/README.md)。

## 仓库约定（所有子项目通用）

* **命名**：子项目目录名即主题名（如 `install`），内部为 `install_*.sh / uninstall_*.sh` 成对脚本；
* **配置**：本机化配置一律走 `*.conf.example` 模板 + 本地 `*.conf`（被 `.gitignore` 排除），不提交真实值；
* **日志**：运行日志统一写 `run.log`（`--clean-log` 可清空历史），不残留 Installer 临时产物；
* **兼容**：同一套脚本跨 AlmaLinux / CentOS / Ubuntu 运行，包管理器自动探测；
* **幂等**：脚本可随时中断，重复执行自动跳过已完成步骤。

## 配套文章

《老刘炼芯》系列文章记录了脚本对应的完整手工过程与原理，欢迎对照阅读：

* 《【老刘炼芯】十款Synopsys芯片设计软件的部署》—— 本文库第一篇，对应 `install/`；
* 公众号「老刘记事儿」回复关键字 **Synopsys Install** 获取脚本压缩包下载链接；
* 更多内容请访问 www.fpga.pw。

## 许可与合规

* 本仓库以 **MIT License** 开源（见 [LICENSE](LICENSE)），欢迎自由使用、修改与贡献；
* 脚本仅提供自动化安装与运维能力，**不包含、不生成任何破解、License 密钥或授权内容**；
* Synopsys 软件安装包与 License 文件（Synopsys.dat）属商业授权资产，请通过**官方正规渠道或公司授权**获得，部署前放入对应子项目的 `license/` 目录（已被 `.gitignore` 排除，请勿提交）。

***

*千里之行，始于足下。老刘的炼芯之路（ASIC 全栈开发），才刚刚开始。*
