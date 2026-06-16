#!/bin/bash
# LinkedEvery 文档同步脚本
# 用途：同步本地文档到 GitHub 仓库

echo "开始同步 LinkedEvery 文档..."

# 进入项目目录
cd /Users/panjuncai/Documents/GitHub/linkedevery

# 添加所有更改
git add .

# 提交更改
echo "请输入提交说明（默认：更新文档）："
read commit_msg
if [ -z "$commit_msg" ]; then
    commit_msg="更新文档"
fi

git commit -m "$commit_msg"

# 推送到远程仓库
git push origin main

echo "同步完成！"
echo "仓库地址：https://github.com/panjc9/linkedevery"
