# 一键部署本 App 会调用的 Edge Functions（与 lib 内 invoke / diaryUrl 等一致）。
# 前置：已执行  npx --yes supabase@latest login
#
# 用法（在 Peture 根目录）：
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy-peture-edge-functions.ps1
#
# 若只需注销相关：
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy-delete-my-account.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

$ref = "dyxbvsnnrzvozcokhlfw"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  Write-Host "未检测到 npx，请先安装 Node.js。" -ForegroundColor Yellow
  exit 1
}

$names = @(
  "chat",
  "delete-my-account",
  "finalize-deletion-if-overdue",
  "purge-due-account-deletions",
  "diary",
  "get-or-create-invitation-code",
  "img-gen-start",
  "img-gen-check-v2",
  "recharge-test",
  "redeem-invitation"
)

Write-Host "将部署 $($names.Count) 个函数到项目 $ref ..." -ForegroundColor Green
foreach ($name in $names) {
  Write-Host "`n>>> $name" -ForegroundColor Cyan
  npx --yes supabase@latest functions deploy $name --project-ref $ref
  if ($LASTEXITCODE -ne 0) {
    Write-Host "部署 $name 失败，退出码 $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
  }
}

Write-Host "`n全部完成。Dashboard -> Edge Functions 核对上述名称。" -ForegroundColor Green
