---
title: "Python 命令行脚本编写规范（argparse 模板）"
summary: "Python CLI 脚本模板，涵盖 argparse、logging、错误处理和并行处理。"
date: 2024-08-20
draft: false
tags: ["Python", "argparse", "CLI"]
categories: ["工具开发"]
author: "Cy257"
showToc: true
TocOpen: false
---

## 脚本规范

一个规范的 CLI 脚本应该具备：

- 清晰的帮助信息
- 完善的参数校验
- 结构化的日志输出
- 优雅的错误处理
- 并行处理支持

<!--more-->

## 完整模板

```python
#!/usr/bin/env python3
"""
Description: 将 FASTA 文件中的序列按长度过滤
Input:       FASTA 格式文件
Output:      过滤后的 FASTA 文件
"""

import argparse
import logging
import sys
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor

VERSION = "1.0.0"
LOGGER_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="按序列长度过滤 FASTA 文件",
        epilog="""示例:
  python filter_fasta.py -i input.fa -o output.fa -m 200
  python filter_fasta.py -i input.fa -o output.fa -m 100 -M 500 -t 8""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("-i", "--input", required=True, help="输入 FASTA 文件")
    parser.add_argument("-o", "--output", required=True, help="输出 FASTA 文件")
    parser.add_argument("-m", "--min-len", type=int, default=0, help="最小长度 (默认: 0)")
    parser.add_argument("-M", "--max-len", type=int, default=0, help="最大长度 (0=不限)")
    parser.add_argument("-t", "--threads", type=int, default=4, help="线程数 (默认: 4)")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG","INFO","WARNING","ERROR"])
    parser.add_argument("--log-file", help="日志输出文件")
    parser.add_argument("--force", action="store_true", help="覆盖已有输出文件")
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    return parser.parse_args()


def main():
    args = parse_args()

    # 日志配置
    handlers = [logging.StreamHandler()]
    if args.log_file:
        handlers.append(logging.FileHandler(args.log_file))
    logging.basicConfig(level=args.log_level, format=LOGGER_FORMAT, handlers=handlers)

    # 输入校验
    if not Path(args.input).exists():
        logging.error(f"输入文件不存在: {args.input}")
        sys.exit(1)
    if Path(args.output).exists() and not args.force:
        logging.error(f"输出文件已存在: {args.output}，使用 --force 覆盖")
        sys.exit(1)

    logging.info(f"开始处理: {args.input}")
    # ... 核心逻辑 ...
    logging.info(f"完成! 输出: {args.output}")


if __name__ == "__main__":
    main()
```

## 关键要点

1. **`argparse`** -- 提供完整的 `-h` 帮助和参数校验
2. **`logging`** -- 替代 `print()`，支持级别和文件输出
3. **`--force`** -- 防止意外覆盖
4. **`--threads`** -- 可选并行处理
5. **`sys.exit(1)`** -- 错误时返回非零退出码
