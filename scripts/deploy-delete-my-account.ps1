# 将 delete-my-account Edge Function 部署到 Supabase 云端。
# 使用 npx，无需 npm install -g supabase（官方已不支持全局 npm 安装）。
#
# 前置（只需做一次）：在本机登录 Supabase
#   npx --yes supabase@latest login
#
# 用法：在 Peture 目录下执行
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy-delete-my-account.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

$ref = "dyxbvsnnrzvozcokhlfw"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  Write-Host "未检测到 npx。请先安装 Node.js (https://nodejs.org/)。" -ForegroundColor Yellow
  exit 1
}

Write-Host "使用 npx supabase@latest 部署 delete-my-account 到项目 $ref ..." -ForegroundColor Green
Write-Host "（首次会下载 CLI，若遇 EPERM 清理警告可忽略，只要后面显示 Deployed 即成功）" -ForegroundColor DarkGray

npx --yes supabase@latest functions deploy delete-my-account --project-ref $ref

if ($LASTEXITCODE -ne 0) {
  Write-Host "部署失败。若提示未登录，请先执行: npx --yes supabase@latest login" -ForegroundColor Yellow
  exit $LASTEXITCODE
}

Write-Host "完成。请到 Dashboard -> Edge Functions 查看 delete-my-account 与日志。" -ForegroundColor Green
