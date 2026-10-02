# Changelog

All notable changes to the Synopsys 芯片设计软件自动化安装 / 启动 / License 校验脚本 will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-02

### Added
- 初始版本发布。

### Verified
- 已在 CentOS 7 环境完成核心指令的实测核验：
  `bash install_all.sh --skip-license --clean-log`、`bash uninstall_all.sh`、`sudo bash license/setup_license.sh`；
- AlmaLinux 8 / Ubuntu 18.04+ 为跨发行版适配目标，请先在测试机验证后再用于正式部署。
