# Flutter + Supabase App 敏感内容审查技术实现方案报告

（面向中国大陆合规 + App Store 审核适配）

## 摘要

本方案针对基于 Flutter + Supabase 开发的面向中国大陆市场的 App，提供全场景敏感内容审查解决方案，核心目标是满足《网络信息内容生态治理规定》《生成式人工智能服务管理办法》等中国大陆监管要求，同时适配 Apple App Store 审核标准。方案采用「前端轻量过滤 + 后端 Supabase Edge Functions 中转 + 第三方合规审查 API 检测」的混合架构，在保障合规的前提下平衡延迟与成本，尤其适配初期用户规模不确定的低预算场景。

## 一、合规性与风险评估

### 1.1 中国大陆监管要求

面向中国大陆用户的 App 必须严格遵守以下核心监管条款，所有审查逻辑均基于这些条款设计：

- **《网络信息内容生态治理规定》** ：要求平台建立「内容审核 - 内容监管 - 内容治理」三级机制，对用户生成内容（UGC）和 AI 生成内容实现全流程闭环管理，明确禁止含政治敏感、色情、暴力、恐怖、民族仇恨、邪教迷信等违法违规内容的传播。

- **《生成式人工智能服务管理办法》** ：AI 生成内容需体现社会主义核心价值观，不得生成危害国家安全、虚假信息等违法内容；必须对生成内容添加显著标识（如 “AI 生成”）；需留存用户输入信息和生成内容日志不少于 60 日。

- **《移动互联网应用程序信息服务管理规定》** ：必须记录用户日志信息并保存 60 日；建立用户举报机制，留存举报处理记录；对违规内容需采取警示、限制功能、关闭账号等处置措施，并向有关主管部门报告。

- **《互联网用户账号名称管理规定》** ：用户 / 宠物头像、昵称属于公开账号标识，不得使用国家领导人姓名 / 肖像、党政机关标识、煽动性词汇等，需符合 “后台实名、前台自愿” 的实名认证原则。

针对 App 内五大核心场景，监管要求的具体适配如下：

|场景类型|监管要求|
|---|---|
|用户 / 宠物头像|禁止使用政治敏感标识、低俗图像；需通过图像审查 API 检测涉政、色情、暴恐元素|
|用户 / 宠物昵称|禁止使用违规词汇、极端表述；需通过文本审查 API 检测敏感词|
|AI 助手|对用户输入和 AI 输出双向审查；过滤违法内容；留存交互日志不少于 60 日|
|成长日记|全量文本审查；过滤违法内容；公开日记需额外通过人工复审（初期可简化为标记后 24 小时内复审）|
|AI 生图实验室|对生成图像和输入 Prompt 双向审查；添加 “AI 生成” 标识；留存生成记录不少于 60 日|
本表格中各场景的监管要求依据：用户 / 宠物头像审查要求参考；用户 / 宠物昵称审查要求参考；AI 助手审查要求参考；成长日记审查要求参考；AI 生图实验室审查要求参考。

### 1.2 App Store 审核要求

Apple 对 UGC 和 AI 类 App 的审核核心要求集中在 **《App Store 审核指南》1.2 安全条款**与 **3.1 内容条款**，需同时满足全球标准与中国大陆区特殊要求：

- **UGC 类通用要求**：必须提供内容过滤机制、用户举报功能、违规用户封禁机制；需公布联系邮箱，确保用户能反馈问题；审查响应时效不得超过 24 小时（高风险场景需在 1 小时内处置）。

- **中国大陆区特殊要求**：若使用第三方审查 API，需确保服务商在中国大陆有合法资质；不得出现违反中国法律法规的内容；需在隐私政策中明确披露审查流程和数据收集范围。

- **AI 生成内容额外要求**：需在 App 内显著标注 AI 生成内容；需在隐私政策中披露 AI 数据收集类型（如 Prompt、生成内容）；若涉及用户输入数据上传至第三方 AI 服务，需获得用户主动授权。

**审核雷区提示**：

- 若仅在前端实现审查（如本地关键词过滤），未部署服务端二次验证，审核员会手动输入敏感词测试，100% 会被拒绝上架。

- 若缺少举报功能或举报响应超时，会直接触发 1.2 条款拒绝，需确保举报按钮在内容详情页的显著位置（如右上角菜单）。

- 若未留存审查日志，审核员可能要求提供近 30 天的审查记录，无法提供会导致审核延迟或拒绝。

## 二、审查技术架构设计

本方案采用「分层过滤 + 边缘计算中转 + 第三方专业审查」的架构，既满足中国大陆数据合规要求（避免客户端直接调用第三方 API 导致的密钥暴露），又适配 Supabase 的无服务器架构优势。

### 2.1 核心架构图

```Plain Text

Flutter 客户端

├── 前端轻量过滤（本地关键词库 + 图像预检测）

├── 调用 Supabase Edge Functions

│   ├── 处理第三方 API 密钥（环境变量存储）

│   ├── 调用合规审查 API（如网易易盾、阿里云）

│   ├── 返回审查结果

│   └── 记录审查日志到 Supabase Database

├── Supabase Storage（存储审核通过的内容）

└── Supabase Database（存储用户信息、审查日志、举报记录）
```

### 2.2 架构优势

1. **安全性**：第三方 API 密钥存储在 Supabase Edge Functions 的环境变量中，客户端仅需调用边缘函数，无需直接接触密钥，彻底避免密钥反编译泄露的风险。

2. **合规性**：边缘函数可在中国大陆节点部署（需在 Supabase 控制台配置区域），避免用户数据出境，满足《数据安全法》对重要数据本地化的要求。

3. **可扩展性**：支持快速切换审查 API 服务商；可灵活调整审查强度（如从纯机器审核升级为 “机器审核 + 人工复审”）；无需修改客户端代码即可完成功能迭代。

4. **成本优化**：通过前端预过滤（如本地关键词库过滤常见敏感词）、边缘函数缓存重复请求等方式，可有效降低第三方 API 的调用量，初期可将调用量减少 30%~50%。

## 三、第三方审查 API 选型与对比

针对初期用户规模不确定、预算较低的场景，推荐以下 **中国大陆合规服务商**（均通过信通院内容安全评估，支持多模态审查）：

### 3.1 推荐服务商对比

|服务商|免费额度|支持类型|响应速度|并发限制|优势场景|计费（超出后）|
|---|---|---|---|---|---|---|
|**网易易盾**|7 天免费试用，含 8 万条文本、5 万张图片|文本、图像、音频、视频、AIGC 专项检测|文本 <100ms，图片 <200ms|文本 200 次 / 秒，图片 64 张 / 秒|全场景审查、高并发、AIGC 检测精度高|文本 25 元 / 万条，图片 15 元 / 万张|
|**阿里云内容安全**|新用户 30 天免费，每日 3000 张图片、1 万条文本|文本、图像、音频、视频、AIGC 专项检测|200-500ms|默认 100 次 / 秒|图像审查精度高、可定制化程度高|文本 15 元 / 万条，图片 15 元 / 万张|
|**腾讯云内容安全**|新用户 15 天免费，3000 条文本、3000 张图片|文本、图像、音频、视频、AIGC 专项检测|100-300ms|内容安全 1000 次 / 秒，AIGC 识别 50 次 / 秒|实时性要求高的场景|文本 25 元 / 万条，图片 20 元 / 万张|
|**图普科技**|1 万次免费调用|文本、图像|50-100ms|100 次 / 秒|低成本、文本审查|文本 8.96 元 / 万条起，图片 10 元 / 万张起|
本表格中各服务商的选型依据：网易易盾的免费额度与优势参考；阿里云内容安全的免费额度与优势参考；腾讯云内容安全的免费额度与优势参考；图普科技的免费额度与优势参考。

### 3.2 选型建议

基于初期用户规模不确定、预算较低的需求，推荐优先级如下：

1. **首选：网易易盾**

- 理由：免费额度高（7 天 8 万条文本、5 万张图片），足以覆盖初期测试和冷启动阶段的审查需求；AIGC 检测精度行业领先（官方测试准确率 >99.5%），支持 Prompt 和生成内容的双向检测；并发限制宽松（文本 200 次 / 秒、图片 64 张 / 秒），无需担心初期用户增长导致的限流问题。

- 注意：免费试用需实名认证，需提前准备企业营业执照（企业开发者）或身份证（个人开发者）完成认证。

1. **备选：阿里云内容安全**

- 理由：新用户免费额度覆盖初期需求；图像审查精度高（支持 90+ 风险标签检测）；可通过资源包进一步降低成本（预付费资源包最低 10 元 / 万次）。

- 注意：AIGC 专项检测需额外开通，默认免费额度不包含该功能，需在控制台手动激活。

1. **备选：图普科技**

- 理由：永久免费额度（1 万次调用）适合纯文本场景（如成长日记、昵称）；单次调用成本低至 0.000896 元 / 次，是所有服务商中最低的。

- 注意：不支持音频 / 视频审查，若 App 后续扩展多媒体场景需额外适配。

**关键提示**：**禁止选择 AWS、Azure 等境外审查服务**—— 一方面，境外服务商的 API 节点不在中国大陆，用户数据出境会违反《数据安全法》；另一方面，App Store 中国区审核会要求提供服务商的中国大陆合规资质，境外服务商无法满足该要求，直接导致审核不通过。

## 四、Supabase + Flutter 具体实现方案

### 4.1 审查时机与模式选择

针对不同场景的风险等级，需设计差异化的审查时机和模式，在保障安全的同时优化用户体验：

|场景类型|审查时机|审查模式|延迟要求|存储策略|
|---|---|---|---|---|
|用户 / 宠物头像|上传前（客户端预检测）+ 上传后（服务端最终检测）|同步审查|<500ms|审核通过前存储在 Supabase Storage 的临时隔离 Bucket（`avatars-temp`），通过后迁移至正式 Bucket（`avatars`）|
|用户 / 宠物昵称|提交修改时|同步审查|<300ms|审核通过前数据库字段标记为 `pending`，通过后更新为 `active`|
|AI 助手|用户输入时 + AI 输出后|同步审查 + 异步二次校验|<1000ms|实时审查通过后展示；异步校验不通过则撤回内容并发送系统通知|
|成长日记|发布时|异步审查（公开）/ 本地审查（私密）|<2000ms|公开日记审核通过前标记为 `draft`；私密日记仅本地存储，无需上传至服务端|
|AI 生图实验室|Prompt 输入时 + 图像生成后|同步审查|<3000ms|审核通过前存储在临时 Bucket（`ai-images-temp`），通过后添加 “AI 生成” 水印并迁移至正式 Bucket（`ai-images`）|
本表格中各场景的审查策略依据：用户 / 宠物头像审查时机与存储策略参考；用户 / 宠物昵称审查时机与存储策略参考；AI 助手审查时机与存储策略参考；成长日记审查时机与存储策略参考；AI 生图实验室审查时机与存储策略参考。

### 4.2 Supabase Edge Functions 核心实现

Supabase Edge Functions 是本方案的核心中转层 —— 它不仅能安全存储第三方审查 API 的密钥（避免客户端暴露敏感信息），还能在边缘节点就近处理审查请求，降低延迟；同时，通过与 Supabase Auth 的集成，可实现基于用户身份的细粒度审查控制。

#### 4.2.1 创建审查函数

以下为调用网易易盾文本审查 API 的示例（Deno 环境）：

**核心需求**：创建基于Deno环境的Supabase Edge Function，作为中转层调用网易易盾文本审查API，实现用户身份验证、文本内容审查、审查结果处理与日志记录，同时避免客户端暴露敏感密钥，保障接口调用安全与合规。

**详细实现思路**：

1. 环境与依赖配置：基于Deno环境开发，引入http服务相关依赖用于启动函数服务，引入supabase-js依赖用于连接Supabase数据库及实现用户身份验证，确保依赖版本适配Edge Functions运行环境。

2. 敏感信息管理：从Supabase Edge Functions环境变量中获取Supabase项目URL、服务角色密钥，以及网易易盾的App Key和Secret Key，避免敏感信息硬编码在代码中，降低泄露风险。

3. 用户身份验证：接收客户端请求头中的Authorization字段，提取JWT Token，通过Supabase Auth接口验证Token合法性，获取当前用户信息；若验证失败（无有效用户或验证报错），返回401未授权响应。

4. 请求参数解析与校验：解析客户端提交的JSON格式请求参数，提取待审查文本内容（content）和场景类型（scene）；若未获取到待审查内容，返回400参数错误响应，确保审查流程有有效输入。

5. 网易易盾API调用：生成符合网易易盾要求的请求参数（时间戳、随机字符串nonce），按照其签名算法生成签名，通过POST请求调用网易易盾文本审查接口，携带appKey、签名、待审查内容、场景类型等参数，其中dataId结合用户ID和时间戳生成，用于审查请求的唯一追踪。

6. 审查结果处理：解析网易易盾返回的审查数据，判断内容是否通过审查（依据返回码和pass字段），提取风险等级和风险标签，封装成统一格式的结果对象，便于客户端解析。

7. 审查日志记录：将审查相关信息（用户ID、待审查内容（截断至500字符）、场景类型、审查结果、风险等级、风险标签、审查时间）插入Supabase的moderation_logs表，用于合规留存和后续问题排查，留存时间符合监管要求（不少于60日）。

8. 响应返回：将处理后的审查结果以JSON格式返回给客户端，设置正确的Content-Type响应头，确保客户端能正常解析。

9. 错误处理：捕获函数运行过程中的所有异常（如接口调用失败、数据库操作异常等），将错误信息（错误描述、堆栈信息、发生时间）插入moderation_errors表，同时返回500内部服务器错误响应，避免函数崩溃且便于问题定位。



#### 4.2.2 部署与配置

部署与配置核心分为三大环节：环境变量设置、函数部署、CORS跨域配置，各环节步骤清晰、环环相扣，具体操作如下：

##### 4.2.2.1 环境变量设置（关键步骤，避免密钥泄露）

环境变量用于安全存储敏感密钥，是函数正常运行的基础，需严格按照以下步骤操作：

1. **操作路径**：登录 Supabase 控制台 → 左侧导航栏找到「Edge Functions」→ 点击顶部「环境变量」→ 点击「添加环境变量」。

2. **核心变量填写（4个，缺一不可）**：
                  `YIDUN_APP_KEY`：登录网易易盾控制台 → 进入「内容安全」→「应用管理」→ 找到对应应用，复制「App Key」粘贴（注意区分测试环境和生产环境，初期建议用测试环境密钥）。

3. `YIDUN_SECRET_KEY`：同上，在网易易盾应用详情页复制「Secret Key」，粘贴后点击「保存」；保存后密钥会自动隐藏，无法再次查看，建议提前备份。

4. `SUPABASE_URL`：回到 Supabase 项目控制台 → 点击左侧「设置」→「项目设置」→「API」，找到「项目 URL」，复制完整链接（格式为 https://xxx.supabase.co）。

5. `SUPABASE_SERVICE_ROLE_KEY`：同上，在「API」页面找到「Service Role Key」（注意与 anon key 区分，Service Role Key 拥有全部权限，仅用于服务端，禁止暴露给客户端），复制后粘贴。

6. **注意事项**：添加完成后，点击每个变量右侧的「生效范围」，勾选「所有函数」，确保 Edge Functions 能正常读取；若后续修改密钥，需重新部署函数才能生效。

##### 4.2.2.2 函数部署（分两步，降低出错率）

函数部署分为本地调试和线上部署，建议先完成本地调试，排查错误后再进行线上部署，确保部署成功率。

###### 第一步：本地调试（推荐，提前排查代码错误）

1. **安装 Supabase CLI**：根据本地系统选择对应命令，执行安装：
                  `
# Windows PowerShell
iwr https://get.supabase.com/cli/windows-x86_64.zip -OutFile supabase.zip; Expand-Archive supabase.zip -DestinationPath C:\supabase; $env:Path += ";C:\supabase"
# Mac Terminal
` `brew install supabase/tap/supabase`

2. **登录 Supabase CLI**：在终端输入 `supabase login`，会弹出浏览器登录页面，登录自己的 Supabase 账号后，终端会提示“Login successful”。

3. **关联项目**：进入本地 Flutter 项目的根目录，终端输入 `supabase link --project-ref 你的项目ID`（项目ID在 Supabase 项目 URL 中，格式为 xxx，即 https://xxx.supabase.co 中的 xxx）。

4. **本地运行函数**：输入 `supabase functions serve moderate-text`，启动本地调试服务，默认端口为 54321，可通过 `http://localhost:54321/functions/v1/moderate-text` 测试函数是否正常响应。

###### 第二步：线上部署（调试无误后执行）

1. **执行部署命令**：在终端输入 `supabase functions deploy moderate-text`，部署过程中会显示进度条，部署成功后会提示“Deployed function moderate-text to https://xxx.supabase.co/functions/v1/moderate-text”。

2. **验证部署结果**：登录 Supabase 控制台 →「Edge Functions」，在函数列表中找到「moderate-text」，点击「测试」，输入测试参数（如 {"content":"测试内容","scene":"nickname"}），点击「运行」，若返回正常的审查结果，说明部署成功。

补充说明：部署完成后，函数会自动同步到全球边缘节点，中国大陆用户的请求会优先分配到国内节点，降低访问延迟。

##### 4.2.2.3 CORS 跨域配置（确保 Flutter 客户端正常调用）

跨域配置用于解决 Flutter 客户端调用函数时的跨域限制，需覆盖本地测试和正式部署场景，具体操作如下：

1. **操作路径**：Supabase 控制台 →「Edge Functions」→ 点击顶部「CORS 设置」→ 找到「允许的来源」，点击「添加来源」。

2. **分场景配置来源**：
                  本地测试：添加 `http://localhost:8080`、`http://127.0.0.1:8080`（Flutter 本地调试默认端口，若修改过端口需对应调整）。

3. 正式部署（iOS 端）：添加 `app://your-app-id`（your-app-id 为 App Store 中的应用 ID，格式为 com.xxx.xxx，可在 Xcode 或 App Store Connect 中查询）。

4. 正式部署（Android 端，若后续扩展）：添加 `android://your-package-name`（your-package-name 为 AndroidManifest.xml 中的 package 名称）。

5. **补充配置**：勾选「允许的方法」中的 GET、POST、OPTIONS（默认已勾选，若未勾选需手动添加）；「允许的标头」保留默认值即可，无需额外修改。

6. **验证配置**：本地启动 Flutter 项目，调用审查函数，若未出现「Access to fetch at ... from origin ... has been blocked by CORS policy」错误，说明配置生效。

#### 4.2.3 Flutter 客户端调用示例

在 Flutter 中，通过 `supabase_flutter` 包的 `functions.invoke` 方法调用审查函数，以下为昵称修改场景的示例代码：

**核心需求**：在Flutter客户端实现昵称审查功能，调用Supabase Edge Functions中的文本审查函数，完成昵称合规检测、审查结果解析、数据库更新及异常处理，确保昵称修改流程合规且用户体验流畅。

**详细实现方法**：

1. 依赖引入：在Flutter项目中导入supabase_flutter包，确保包版本与Supabase项目适配，为调用Supabase相关接口提供基础支持。

2. 函数定义：创建异步函数moderateNickname，接收用户输入的昵称作为参数，返回布尔值标识审查及修改操作是否成功。

3. 函数调用：通过Supabase.instance.client.functions.invoke方法，调用Supabase Edge Functions中名为moderate-text的审查函数；请求头需携带当前用户的Authorization令牌（确保用户身份合法）和Content-Type（指定请求格式为JSON）；请求体传入待审查的昵称内容和场景类型（scene设为nickname，适配网易易盾的场景化审查策略）。

4. 结果解析：将审查函数返回的响应数据转为Map类型，提取审查结果（passed字段），判断昵称是否通过合规检测。

5. 结果处理：若审查通过，调用Supabase数据库接口，更新profiles表中当前用户（通过Supabase Auth获取当前用户ID）的nickname字段，返回true表示操作成功；若审查不通过，提取风险标签（riskLabels字段），抛出包含违规原因的异常，用于前端向用户展示具体违规提示。

6. 异常捕获：通过try-catch捕获整个流程中的异常（如函数调用失败、数据库更新异常、数据解析错误等），打印错误信息便于排查问题，并返回false表示操作失败，避免程序崩溃。

### 4.3 数据库触发器与审查日志

#### 4.3.1 自动触发审查

为确保关键场景（如昵称修改、日记发布）的审查不被绕过，需在 Supabase Database 中创建触发器，当数据插入 / 更新时自动触发审查逻辑：

**自动触发审查实现方法**：为确保昵称修改场景的审查不被绕过，需在Supabase Database中创建触发器及关联函数，实现昵称更新时自动触发审查逻辑，具体方法如下：

1. **创建审查触发函数**：定义一个触发器函数，该函数的核心功能是调用Supabase Edge Functions中的文本审查函数。函数内部需构建合法的请求参数，包含待审查的新昵称内容、场景类型（nickname）、当前用户ID，同时携带Supabase服务角色密钥作为授权凭证，确保接口调用的安全性；请求格式需转为JSON格式，符合审查函数的接收要求，调用完成后返回新的昵称数据。

2. **创建触发器关联表字段**：创建触发器，设置触发时机为profiles表中nickname字段更新后，触发范围为每一行数据，触发时执行上述创建的审查触发函数。这样一来，每当用户修改昵称、更新profiles表的nickname字段时，会自动触发审查流程，无需手动调用审查接口，保障审查的全面性和有效性。

**注意**：需先安装 `http` 扩展（用于 Postgres 调用外部 API），执行以下 SQL 命令：

```Plain Text

CREATE EXTENSION IF NOT EXISTS http;
```

#### 4.3.2 审查日志表设计

为满足监管要求（留存审查记录不少于 60 日），需创建 `moderation_logs` 表存储审查记录：

**审查日志表实现方法**：为满足监管要求（审查记录留存不少于60日），需创建审查日志表，用于存储所有审查相关信息，同时配置索引优化查询效率、设置RLS策略保障数据安全，具体实现方法如下：

1. **表结构设计**：核心字段需包含唯一标识ID、关联用户ID（与用户表关联，用户删除时同步删除对应日志）、待审查内容（截取前500字符，避免冗余）、审查场景（明确区分昵称、头像、日记等场景）、审查结果（通过、拒绝、待审核三种状态）、风险等级（高、中、低、无四级）、风险标签数组（存储具体违规类型，如涉政、色情等）、审查时间（默认取当前时间，带时区）、第三方API原始响应（用于后续问题排查）。

2. **索引配置**：为提升查询效率，需针对高频查询场景创建索引，分别基于用户ID、审查场景、审查时间创建索引，确保后续按这三类条件查询日志时速度更快，适配多场景排查需求。

3. **RLS策略配置**：为保障数据隐私与安全，配置两种RLS策略：一是允许用户查看自身的审查日志，确保用户仅能获取与自己相关的审查记录；二是允许管理员（service_role角色）查看所有审查日志，方便管理员进行全局审核管理和问题排查。

该表的设计依据：《移动互联网应用程序信息服务管理规定》要求留存用户日志不少于 60 日；《生成式人工智能服务管理办法》要求留存 AI 生成内容记录。

### 4.4 存储规则与安全策略

Supabase Storage 的文件上传审查需通过 RLS 策略和 Bucket 隔离实现，避免违规文件落地存储：

#### 4.4.1 隔离 Bucket 设计

创建两个 Bucket 实现审核前后的文件隔离：

|Bucket 名称|权限策略|用途|
|---|---|---|
|`avatars-temp`|仅允许认证用户上传；禁止公开访问；文件保留 24 小时后自动删除|存储待审核的用户 / 宠物头像|
|`avatars`|仅允许认证用户访问自己的文件；公开访问需通过 RLS 策略授权|存储审核通过的用户 / 宠物头像|
**自动删除规则配置**：在 Supabase 控制台的「Storage」→「Bucket 设置」中，为 `avatars-temp` Bucket 配置「自动删除」规则，设置文件保留时间为 24 小时 —— 这可避免待审核文件占用过多存储资源，同时符合监管对临时文件的清理要求。

#### 4.4.2 RLS 策略示例

以下为 `avatars-temp` Bucket 的 RLS 策略，确保只有认证用户能上传文件，且文件只能被自己访问：

```Plain Text

\-- 启用 Bucket 的 RLS 策略

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

\-- 策略：仅允许认证用户上传到 avatars-temp Bucket

CREATE POLICY "Authenticated users can upload to avatars-temp"

ON storage.objects

FOR INSERT TO authenticated

WITH CHECK (bucket\_id = 'avatars-temp' AND owner = auth.uid());

\-- 策略：仅允许用户访问自己上传的临时头像文件

CREATE POLICY "Users can access their own temp avatars"

ON storage.objects

FOR SELECT TO authenticated

USING (bucket\_id = 'avatars-temp' AND owner = auth.uid());

\-- 策略：禁止公开访问临时 Bucket

CREATE POLICY "No public access to avatars-temp"

ON storage.objects

FOR SELECT TO anon

USING (bucket\_id != 'avatars-temp');
```

该策略的设计依据：Supabase Storage 的 RLS 权限控制规范；《网络信息内容生态治理规定》对用户数据的保护要求。

## 五、App Store 审核适配

### 5.1 功能合规检查清单

为确保通过 App Store 审核，需完成以下功能适配：

|检查项|要求|实现方式|
|---|---|---|
|举报功能|内容详情页有明显的 “举报” 按钮；支持至少 6 类违规标签（隐私侵权、广告、人身攻击、涉政、色情、暴恐）；24 小时内反馈处理结果|在 Flutter 中添加举报弹窗；调用 Supabase Edge Functions 记录举报信息；后台通过邮件或系统通知反馈结果|
|社区准则|App 内有明确的社区准则页面；在用户注册 / 首次使用时展示|在 Flutter 中添加静态页面；注册流程中增加 “同意社区准则” 的勾选框|
|封禁机制|支持封禁违规用户；封禁后用户无法发布内容或使用核心功能|在 Supabase Auth 中设置用户状态；通过 RLS 策略限制封禁用户的访问权限|
|联系信息|App 内有明确的联系邮箱；在 App Store Connect 中填写相同的联系邮箱|在 Flutter 设置页面添加邮箱链接；在 App Store Connect 的「App 信息」中填写|
|AI 生成内容标识|AI 生成内容需添加显著标识（如 “AI 生成”）；标识位置不影响内容查看|在 Flutter 中为 AI 生成图像添加水印；为 AI 助手输出添加前缀文本|
本表格中各检查项的实现依据：举报功能要求参考；社区准则要求参考；封禁机制要求参考；联系信息要求参考；AI 生成内容标识要求参考。

### 5.2 审核备注与文档提交

在 App Store Connect 的「审核备注」中需提供以下信息，帮助审核员快速验证合规性，具体要求如下：

#### 5.2.1 内容审查机制说明

本 App 采用「前端预过滤 + 服务端 Supabase Edge Functions 中转 + 网易易盾审查 API」的三层审查架构：

- 前端：通过本地关键词库过滤常见敏感词，实现初步风险拦截；

- 服务端：通过 Supabase Edge Functions 调用网易易盾的文本/图像审查 API，对所有用户生成内容和 AI 生成内容进行二次检测；

- 人工复审：高风险内容会标记为待人工复审，初期由开发者本人在 24 小时内完成审核。

#### 5.2.2 第三方审查服务商资质

本 App 使用网易易盾作为内容审查服务商，该服务商已获得信通院内容安全评估最高级别认证，具备中国大陆合规资质，可满足 App Store 中国区审核对服务商资质的要求。

#### 5.2.3 测试账号

- 提供 1-2 个测试账号，示例：账号 `test@example.com`，密码 `Test123456`；

- 附各场景测试方法，示例：修改昵称时输入敏感词，会触发审查不通过提示；上传违规头像，会被拦截并提示合规要求。

#### 5.2.4 文档提交要求

- 无需提交单独的审查机制文档，但需确保 App 内社区准则页面内容清晰、无歧义，便于审核员查看；

- 若 App 涉及 AI 生成内容，需在隐私政策中明确披露 AI 数据收集类型（如 Prompt、生成内容），并说明数据用途（仅用于内容审查和服务优化），避免审核遗漏。

## 六、成本预估（初期用户规模）

基于初期用户规模（0-1 万日活），成本预估如下：

### 6.1 第三方审查 API 成本

假设初期用户行为数据如下：

- 日均文本审查请求：1 万次（昵称、AI 助手、成长日记）

- 日均图像审查请求：2000 次（头像、AI 生图）

- 场景分布：文本场景占 80%（昵称、AI 助手），图像场景占 20%（头像、AI 生图）

|服务商|免费额度覆盖情况|超出后月成本|年成本|
|---|---|---|---|
|网易易盾|7 天免费试用覆盖初期测试；后续可购买资源包|约 100-200 元|约 1200-2400 元|
|阿里云内容安全|30 天免费覆盖初期需求；后续可购买资源包|约 150-300 元|约 1800-3600 元|
|图普科技|1 万次免费调用覆盖纯文本场景；图像场景需付费|约 50-100 元|约 600-1200 元|
本表格中各服务商的成本计算依据：网易易盾的资源包定价参考；阿里云内容安全的资源包定价参考；图普科技的按量计费定价参考。

### 6.2 Supabase 资源成本

Supabase 的免费计划（Free Tier）已完全覆盖初期需求：

|资源类型|免费额度|超出后成本|
|---|---|---|
|数据库|500MB 存储、1GB 带宽|25 美元 / 月起|
|存储|1GB 存储、1GB 带宽|0.021 美元 / GB / 月|
|Edge Functions|100 万次调用 / 月、10GB 带宽|0.00001 美元 / 次|
**注意**：免费计划有一个关键限制 —— 若项目连续 7 天无用户访问，会自动暂停服务。需通过 GitHub Actions 配置保活脚本（如每日发送一次请求），避免服务中断。

### 6.3 总成本预估

初期（0-1 万日活）的总成本约为 **100-300 元 / 月**，主要为第三方审查 API 的资源包费用；Supabase 资源成本几乎为 0，适合低预算场景。

## 七、**实施** **参考** **建议**

结合方案各模块关联性，将实施流程拆解为5个阶段，其中多个阶段可并行推进，总周期控制在7-10天，明确各任务责任人、具体动作及交付物，确保落地可行，具体安排如下：

### 一、前期准备阶段（第1-2天，可与“开发阶段”并行启动）

**责任人**：后端开发1名、运维1名

**核心任务（并行推进）**：

1. 第三方审查服务商对接（0.5天）：注册网易易盾/阿里云账号，完成企业/个人实名认证；创建应用，获取文本、图像审查API的App Key、Secret Key（区分测试环境与生产环境）；测试API调用有效性，确保能正常返回审查结果。

2. Supabase环境配置（1天）：运维人员登录Supabase控制台，进入Edge Functions配置环境变量，准确录入第三方API密钥（YIDUN_APP_KEY、YIDUN_SECRET_KEY等）、Supabase项目URL及Service Role Key；配置完成后测试变量读取有效性，避免密钥泄露。

3. 需求梳理与测试准备（1.5天，后端+前端配合）：梳理各场景审查需求（昵称、头像、AI生图等），明确各场景审查阈值、错误提示文案；准备测试用例（含敏感词、违规图像、违规Prompt等），搭建测试表格，用于后续全场景验证。

**交付物**：API密钥清单、Supabase环境变量配置截图、测试用例表格、需求梳理文档。

### 二、核心开发阶段（第2-6天，与前期准备阶段并行1天，与配置阶段并行2天）

**责任人**：后端开发2名、前端开发1名

**核心任务（并行推进）**：

1. Supabase Edge Functions开发（3天，后端1负责）：开发文本审查函数、图像审查函数，实现用户身份验证、API中转调用、审查结果解析、日志记录及异常处理；本地调试通过后，部署至线上，测试函数响应速度（确保符合各场景延迟要求）。

2. Flutter客户端调用开发（2.5天，前端负责）：基于supabase_flutter包，实现各场景审查调用逻辑（昵称修改、头像上传、AI助手输入/输出、成长日记发布、AI生图）；开发违规提示弹窗、加载状态提示，确保用户体验流畅；对接后端审查函数，完成本地联调。

3. 数据库与触发器开发（2天，后端2负责）：创建moderation_logs审查日志表，配置索引及RLS策略；创建数据库触发器，实现昵称修改、日记发布等场景的自动审查；测试触发器触发有效性，确保审查不被绕过。

**交付物**：Edge Functions代码及部署截图、Flutter客户端审查调用代码、数据库表结构脚本、触发器测试报告。

### 三、配置与适配阶段（第4-7天，与开发阶段并行2天，与测试阶段并行1天）

**责任人**：后端开发2名、运维1名、产品1名

**核心任务（并行推进）**：

1. Supabase Storage配置（1天，运维负责）：创建avatars-temp（临时）、avatars（正式）两个Bucket，配置自动删除规则（temp Bucket文件保留24小时）；配置RLS策略，确保认证用户仅能上传、访问自身文件，禁止临时Bucket公开访问。

2. App Store审核适配（2天，产品+前端负责）：前端开发社区准则静态页面，在注册流程中添加“同意社区准则”勾选框；在内容详情页添加举报弹窗（支持6类违规标签）；为AI生成内容添加“AI生成”水印/前缀；产品整理App Store审核备注、测试账号，完善隐私政策中AI数据收集披露内容。

3. 权限与安全配置（1天，后端2负责）：配置Supabase Auth用户状态管理（封禁机制），通过RLS策略限制封禁用户访问权限；检查所有API调用的权限控制，确保敏感接口不被非法调用；备份数据库及环境配置，避免数据丢失。

**交付物**：Bucket配置截图、RLS策略脚本、App内社区准则/举报功能截图、审核备注文档、测试账号清单。

### 四、全场景测试阶段（第6-8天，与配置阶段并行1天，与提交审核阶段并行1天）

**责任人**：测试1名、前端1名、后端1名

**核心任务（并行推进）**：

1. 功能测试（1.5天，测试负责）：按照测试用例，全场景验证审查功能（昵称敏感词拦截、头像违规拦截、AI生图违规Prompt拦截等）；测试审核日志记录完整性、触发器触发准确性、Bucket文件迁移有效性；记录测试Bug，提交至开发人员修复。

2. 性能与兼容性测试（1天，测试+前端负责）：测试各场景审查延迟（确保符合<300ms、<500ms等要求）；测试Flutter客户端在不同iOS版本的兼容性，确保审查功能正常运行；测试Edge Functions并发调用稳定性。

3. Bug修复与回归测试（1.5天，开发+测试负责）：开发人员修复测试中发现的Bug，测试人员进行回归测试，确保所有Bug全部修复；验证修复后功能的完整性，避免出现新的问题。

**交付物**：测试报告（含Bug清单及修复情况）、性能测试数据、兼容性测试报告。

### 五、提交审核与上线准备阶段（第7-10天，与测试阶段并行1天）

**责任人**：产品1名、运维1名、前端1名

**核心任务（并行推进）**：

1. App Store提交准备（1天，产品负责）：在App Store Connect中填写应用元数据（联系信息、应用描述等），上传应用安装包；填写审核备注，提交第三方审查服务商资质、测试账号及测试方法；确认所有合规项均已完成。

2. 上线前最终检查（1天，运维+前端+后端负责）：检查Supabase环境、Edge Functions、数据库、Storage配置是否正常；检查客户端审查功能、举报功能、社区准则等是否正常；测试测试账号能否正常使用，审核备注信息是否准确。

3. 提交审核与后续准备（1-2天，产品+运维负责）：提交App Store审核，实时关注审核进度；准备审核回复话术，应对审核过程中可能出现的问题；配置Supabase保活脚本，避免免费计划服务中断；整理实施文档，用于后续维护。

**交付物**：App Store提交截图、上线检查清单、实施文档、保活脚本。

**关键说明**：各阶段并行推进可缩短总周期，若团队人员不足，可适当延长1-2天；优先完成核心审查功能（昵称、头像）的开发与测试，确保核心场景合规，再推进次要场景（AI生图、成长日记）。





## 参考资料

1. [生成式人工智能服务管理暂行办法_国家互联网信息办公室_中国政府网](https://www.gov.cn/zhengce/202311/content_6917778.htm)

2. [生成式人工智能服务管理暂行办法[国家网信办等部门公布的暂行办法]_百科](https://m.baike.com/wiki/%E7%94%9F%E6%88%90%E5%BC%8F%E4%BA%BA%E5%B7%A5%E6%99%BA%E8%83%BD%E6%9C%8D%E5%8A%A1%E7%AE%A1%E7%90%86%E6%9A%82%E8%A1%8C%E5%8A%9E%E6%B3%95/7255284458647475491)

3. [生成式人工智能服务管理暂行办法](https://www.miit.gov.cn/zcfg/qtl/art/2023/art_f4e8f71ae1dc43b0980b962907b7738f.html)

4. [中央 网信 办 部署 开展 “ 清朗 · 整治 AI 技术 滥用 ” 专项 行动 ！ 规范 AI 服务 和 应用 ， 促进 行业 健康 有序 发展 ， 保障 公民 合法 权益 ！ # 中国 网信 # 清朗](https://www.iesdouyin.com/share/video/7506057882615237923)

5. [大模型备案全解析:从《生成式人工智能服务安全基本要求》看合规治理三大核心维度_生成式人工智能安全治理有哪些主体-CSDN博客](https://blog.csdn.net/chuangfumao/article/details/147609121)

6. [国家互联网信息办公室 中华人民共和国国家发展和改革委员会 中华人民共和国教育部 中华人民共和国科学技术部 中华人民共和国工业和信息化部 中华人民共和国公安部 国家广播电视总局令(第15号) 生成式人工智能服务管理暂行办法__2023年第24号国务院公报_中国政府网](http://www.gov.cn/govweb/gongbao/2023/issue_10666/202308/content_6900864.html)

7. [生成式人工智慧服务管理暂行办法_国务院部门文件_中国政府网](http://big5.www.gov.cn/gate/big5/www.gov.cn/zhengce/zhengceku/202307/content_6891752.htm)

8. [生成式人工智能服务管理暂行办法](https://world.moleg.go.kr/cms/commonDown.do?DLD_CFM_NO=TRIM9GRUO0WKU0HPNK2H&FL_SEQ=75573)

9. [网络信息内容生态治理规定_国家互联网信息办公室_中国政府网](http://big5.www.gov.cn/gate/big5/www.gov.cn/zhengce/2019-12/20/content_5728944.htm)

10. [网络信息内容生态治理规定_国家互联网信息办公室_中国政府网](https://www.gov.cn/zhengce/2019-12/20/content_5728944.htm)

11. [网络信息内容生态治理规定[2019年国家互联网信息办公室发布的规定]_百科](https://m.baike.com/wiki/%E7%BD%91%E7%BB%9C%E4%BF%A1%E6%81%AF%E5%86%85%E5%AE%B9%E7%94%9F%E6%80%81%E6%B2%BB%E7%90%86%E8%A7%84%E5%AE%9A/22894885)

12. [高昌网信普法明确网民网络信息发布禁止内容](https://www.iesdouyin.com/share/video/7519816625429761339)

13. [互联网企业内容审核与监管指南-20260317211331.docx-原创力文档](https://m.book118.com/html/2026/0317/7113142060011062.shtm)

14. [互联网内容审核与监管操作手册-20260310.docx - 人人文库](https://www.renrendoc.com/paper/512982935.html)

15. [网络信息内容生态治理规定 - 中共南充市委网络安全和信息化委员会办公室](https://www.ncwxw.gov.cn/sys-nd/1452.html)

16. [网络信息内容生态治理规定_中央网络安全和信息化委员会办公室](https://www.cac.gov.cn/2019-12/20/c_1578375159509309.htm?from=timeline&isappinstalled=0)

17. [App 审核指南 - Apple 开发者](https://developer.apple.com/cn/app-store/review/guidelines/)

18. [如何建立UGC合规性内容审核体系_人人都是产品经理](http://m.toutiao.com/group/7584643545709986338/)

19. [App Store审核六次被拒经验总结：四大避坑指南解析](https://www.iesdouyin.com/share/video/7548419111300500771)

20. [iOS应用审核避坑指南:如何正确处理用户生成内容(UGC)以符合Apple审核1.2安全条款_SSSSSStacker-音视频技术专区](https://devpress.csdn.net/avi/698b74ae0a2f6a37c59116e3.html)

21. [ios 一直是正在等待审核_iOS上架AppStore为什么这么难?这些审核机制你必须要注意...-CSDN博客](https://blog.csdn.net/weixin_42423349/article/details/112088468)

22. [人机协同发力!UGC论坛内容审核，筑牢iOS合规底线_要求_违规_用户](https://m.sohu.com/a/967210029_122575987/)

23. [The Complete Guide to Content Review in China](https://appinchina.co/blog/the-complete-guide-to-content-review-in-china/)

24. [App 审核 - 分发 - Apple 开发者](https://developer.apple.com/cn/app-store/review/rejections/)

25. [iOS应用审核避坑指南:如何正确处理用户生成内容(UGC)以符合Apple审核1.2安全条款_SSSSSStacker-音视频技术专区](https://devpress.csdn.net/avi/698b74ae0a2f6a37c59116e3.html)

26. [2025年苹果开发者App Store上架流程与合规指南](https://www.iesdouyin.com/share/video/7504485634222296355)

27. [如何建立UGC合规性内容审核体系_人人都是产品经理](http://m.toutiao.com/group/7584643545709986338/)

28. [安卓应用下载(Android App Store)系统商城上架要求有那些注意事项?一、应用资质与合规性要求**** 1. - 掘金](https://juejin.cn/post/7573525927792459802)

29. [生成式人工智能服务管理暂行办法](https://www.miit.gov.cn/zcfg/qtl/art/2023/art_f4e8f71ae1dc43b0980b962907b7738f.html)

30. [特殊品类标准 | 小米澎湃OS开发者平台](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1509)

31. [钉钉AI助理市场审核标准](https://terms.alicdn.com/legal-agreement/terms/common_platform_service/20240201124255247/20240201124255247.html)

32. [宝宝 们 ， 我 不 太 懂 ， 可以 问 一下 ， 那 我 以后 还 可以 用 AI 生成 他们 两个 人 的 合照 吗 ？](https://www.iesdouyin.com/share/video/7619700622594693733)

33. [AI生成内容不得侵害他人肖像权!新规全文来了](https://china.huanqiu.com/article/4Dh3VriNAF2)

34. [@内容创作者 AI生成内容必须“亮明身份”](https://m.gmw.cn/2025-09/01/content_1304131835.htm)

35. [国家互联网信息办公室关于《生成式人工智能服务管理办法(征求意见稿)》公开征求意见的通知_中央网络安全和信息化委员会办公室](https://www.cac.gov.cn/2023-04/11/c_1682854275475410.htm?ref=aify.tech)

36. [AI生成内容强制“打标”，内容安全治理迈出关键一步-新华网](http://www.xinhuanet.com/digital/20250902/d08b592223954340af8c02ac3d7161e1/c.html)

37. [App 审核指南 - Apple 开发者](https://developer.apple.com/cn/app-store/review/guidelines/)

38. [iOS应用发布紧急避雷:这些审核规则更新你必须立刻知道-CSDN博客](https://blog.csdn.net/VarFlow/article/details/153326727)

39. [AI生成内容新规实施：需标注并面临法律风险](https://www.iesdouyin.com/share/video/7545109023402593574)

40. [App 审核 - 分发 - Apple 开发者](https://developer.apple.com/cn/app-store/review/rejections/)

41. [苹果应用商店AppStore审核中文指南 分类: ios相关 ...-CSDN博客](https://blog.csdn.net/weixin_33895016/article/details/93550930)

42. [app上架app store审核指南 - AppleByMe-专业代上架苹果市场服务系统](https://www.applebyme.cn/Article/show/15800)

43. [iOS第101篇:App Store审核指南_app store 审核指南-CSDN博客](https://blog.csdn.net/I_did_it/article/details/149866048)

44. [App Store 审核指南_如果 app 包含,显示或会访问第三方内容吗-CSDN博客](https://blog.csdn.net/a332060679/article/details/104162700)

45. [从过审到推荐，一文搞懂上架流程:2025苹果AppStore全流程实战手册-腾讯新闻](https://news.qq.com/rain/a/20250821A09EEU00)

46. [2025年苹果开发者App Store上架流程与合规指南](https://www.iesdouyin.com/share/video/7504485634222296355)

47. [苹果App如何完成ICP备案?需提交哪些材料?_编程语言-CSDN问答](https://ask.csdn.net/questions/9247339)

48. [苹果商店上架的法律合规要求 – 苹果签名-苹果APP签名-超级签名-企业签tf签靠谱签名平台](https://appqianming.com/%e8%8b%b9%e6%9e%9c%e5%95%86%e5%ba%97%e4%b8%8a%e6%9e%b6%e7%9a%84%e6%b3%95%e5%be%8b%e5%90%88%e8%a7%84%e8%a6%81%e6%b1%82/)

49. [appstore视频类app上架要求介绍? - AppleByMe-专业代上架苹果市场服务系统](https://www.applebyme.cn/Article/show/10576)

50. [ios上架app资制需要什么?-APP上架-一门科技](https://www.yimenapp.net/knowledge/appup-59547.html)

51. [网信办发布APP信息服务管理规定 对注册用户身份认证](https://m.chinanews.com/wap/detail/zw/cj/2016/06-28/7919604.shtml)

52. [移动互联网应用程序信息服务管理规定-武汉市互联网行业网上党群服务中心](https://www.whhlwdj.gov.cn/view/4171.html)

53. [直播电商新规强化AI监管并实施三年数据保存](https://www.iesdouyin.com/share/video/7592953344831573745)

54. [工业和信息化部关于进一步提升移动互联网应用服务能力的通知_国务院部门文件_中国政府网](https://www.gov.cn/zhengce/zhengceku/2023-03/02/content_5744106.htm)

55. [移动互联网应用程序信息服务管理规定_中央网络安全和信息化委员会办公室](http://www.cac.gov.cn/2016-06/28/c_1119122192.htm)

56. [国家网信办发布《移动互联网应用程序信息服务管理规定》【3】--时政--人民网](http://politics.people.com.cn/n1/2016/0628/c1001-28503020-3.html)

57. [移动互联网应用程序信息服务管理规定-规范性文件-深圳市互联网违法和不良信息举报办公室](http://szwljb.sz.gov.cn/flfg/gfxwj/content/post_240138.html)

58. [互联网用户账号名称管理规定_中央网络安全和信息化委员会办公室](https://www.cac.gov.cn/2015-02/04/c_1114246561.htm?data1=KeeRevv2v2v2v2)

59. [今日头条合规发文自查清单_华哥观世界](http://m.toutiao.com/group/7615454852626104874/)

60. [# 新手 宠物 博主 起步 三 不要 # 

一 、 不要 用 旧 账号 

旧 号 可能 有 违规 、 内容 杂乱 ， 就算 新 内容 再好 ， 也 难 有 曝光 ， 想 做 垂直 宠物 号 ， 直接 开 新号 从头 来 ； 

二 、 内容 不要 太 老实 

别 原图 当 封面 、 随便 写 标题 ！ 比如 拍 猫咪 晒太阳 ， 标题 写 “ 我家 猫 好 可爱 ” 不如 “]([https://www.iesdouyin.com/share/video/7618123469180680187)](https://www.iesdouyin.com/share/video/7618123469180680187))

1. [专家解读:“微信十条”之后，“账号十条”出台--时政--人民网](http://politics.people.com.cn/n/2015/0204/c1001-26509031.html)

2. [网信办发文规范网民注册网络账号头像](https://china.huanqiu.com/article/9CaKrnJHsqc)

3. [本站用户『发布内容/评论』管理制度-万伯智业 | 让组织管理更至简-与企业共致远](https://www.icucp.com/archives/354231)

4. [关于企鹅号通过试运营的期限和条件的公告_腾讯内容开放平台](https://om.qq.com/notice/a/20170406/032464.htm)

5. [按量付费模式计费规则与价格-内容安全-阿里云](https://help.aliyun.com/document_detail/2872706.html)

6. [AWS内容审核API实战:如何用AI辅助开发提升审核效率与准确性_Hello亲431-音视频技术专区](https://devpress.csdn.net/avi/699359cb0a2f6a37c5921a89.html)

7. [文本内容安全 文本内容安全服务_腾讯云](https://cloud.tencent.cn/document/product/1124/37118)

8. [字节 跳动 See dance 2 . 0 ： AI 视频 生成 进入 “ 明码 标价 ” 的 商业化 新 阶段 # see dance 2 # AI 视频 # 视频 生成 # AI 漫 剧 # API](https://www.iesdouyin.com/share/video/7613815212914920704)

9. [审核智能体功能计费模式详解-内容安全-阿里云](https://help.aliyun.com/document_detail/3013126.html)

10. [Content Moderator](https://azure.microsoft.com/en-us/pricing/details/cognitive-services/content-moderator/)

11. [违规文字识别_文本审核_文本检测_在线检测_图普科技](https://shenhe.tuputech.com/text)

12. [ANTIPORN 文档](https://bce-cdn.bj.bcebos.com/p3m/pdf/ai-cloud-share/online/ANTIPORN/ANTIPORN.pdf?timeStamp=1770595200081)

13. [百度智能云内容审核(免费版)实战:如何高效集成与性能调优_BugBUG120-音视频技术专区](https://devpress.csdn.net/avi/697a497f7c1d88441d903f3b.html)

14. [文本合规_内容审核_内容安全检测-讯飞开放平台](https://www.ai-changsha.com/services/preview-text)

15. [腾讯云内容审核服务：高效精准全方位守护](https://www.iesdouyin.com/share/video/7527243418607586614)

16. [视频内容安全 创建视频审核任务_腾讯云](https://cloud.tencent.com.cn/document/api/1265/80017)

17. [FAQs](http://scana-docs.yunaq.com/api/faq)

18. [图片内容安全 图片异步检测_腾讯云](https://cloud.tencent.com/document/api/1125/87021)

19. [COS数据护航_COS内容审核特惠_COS数据处理活动- 腾讯云](https://cloud.tencent.com/act/pro/content_audit)

20. [Use Supabase with Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)

21. [Flutter Client Library](https://supabase.com/docs/reference/dart/v1/stream)

22. [Flutter功能扩展插件functions_client的使用](http://bbs.itying.com/topic/678b1ede24cdd5004b44b629)

23. [Supabase：开源BaaS平台解析与 Firebase替代优势](https://www.iesdouyin.com/share/video/7568750312140360986)

24. [Supabase Codegen Flutter](https://pub.dev/documentation/supabase_codegen_flutter/2.0.0/index.html)

25. [Supabase - Flutter](https://github.com/adityathakurxd/supabase_flutter)

26. [supabase_flutter 2.12.0](https://pub.dev/packages/supabase_flutter/example)

27. [Flutter Client Library](https://supabase.com/docs/reference/dart/functions-invoke)

28. [对语言模型流式输出文字进行文本审核-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/document_detail/2642626.html)

29. [什么是 Azure AI 内容安全? - Azure AI services | Microsoft Learn](https://learn.microsoft.com/zh-cn/azure/ai-services/content-safety/overview)

30. [内容审核 | 机器学习 | Amazon Web Services](https://aws.amazon.com/cn/ai/use-cases/content-moderation/)

31. [SUNO 生成 无 上限 ！ # CQ TAI # AI # SUNO # API # 大模型](https://www.iesdouyin.com/share/video/7618124485133297051)

32. [使用API提交视频文件审核与AIGC检测任务并获取结果-内容安全-阿里云](https://help.aliyun.com/document_detail/2505810.html)

33. [大模型能力构建的文本审核方案-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/document_detail/2866911.html)

34. [文本内容安全 文本内容安全服务_腾讯云](https://cloud.tencent.com/document/api/1124/51860)

35. [千象API接口文档 – Hidream AI 开放平台](https://hidreamai.com/doc)

36. [Developing Edge Functions locally](https://supabase.com/docs/guides/functions/local-quickstart)

37. [Testing your Edge Functions](https://supabase.com/docs/guides/functions/unit-test)

38. [Routing](https://supabase.com/docs/guides/functions/http-methods)

39. [supabase/apps/docs/content/guides/functions/quickstart-dashboard.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/functions/quickstart-dashboard.mdx)

40. [[supabase] Edge Functions 사용하기](https://velog.io/@yoosk5485/supabase-Edge-Functions-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0-i0s4kfyl)

41. [Edge Functions](https://docs.weweb.io/workflows/actions/supabase/invoke-edge-function.html)

42. [Getting Started with Edge Functions (Dashboard)](https://supabase.com/docs/guides/functions/quickstart-dashboard)

43. [@vettly/supabase](https://www.npmjs.com/package/@vettly/supabase)

44. [图片审核增强版AIGC场景检测服务-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/document_detail/2672918.html)

45. [2026 内容合规 API 选型:6 大主流内容风控检测系统对比 | PingCode智库](https://docs.pingcode.com/baike/5233177)

46. [内容安全_云盾_违规内容识别_安全-阿里云](https://www.aliyun.com/product/lvwang)

47. [网信 部 整治 无 ai 标识 虚假 内容 ， ai 内容 审核 深度 布局 公司 梳理 # ai 内容 审核 # ai # ai 应用 # 股票 # 股票 知识](https://www.iesdouyin.com/share/video/7605932093620718899)

48. [AIGC 时代内容合规指南:2026 年 8 款智能审核工具横评_易盾_网页_ScanA](https://m.sohu.com/a/990875191_120082794/)

49. [文本内容安全 文本内容安全服务_腾讯云](https://cloud.tencent.com/document/api/1124/51860)

50. [AIGC内容安全检测_GPT智库_内容智能审核_公文写作平台_错别字校对_图片|视频|文本审核_敏感违规内容监测-博特智能-首页_8](https://o.botsmart.cn/)

51. [天御内容安全解决方案_内容审核解决方案-腾讯云](https://cloud.tencent.cn/solution/content-security)

52. [通过SDK与HTTPS原生调用接入文本审核增强版PLUS服务-内容安全-阿里云](https://help.aliyun.com/document_detail/433945.html)

53. [图文混合模态审核大模型服务-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/zh/document_detail/2974985.html)

54. [基于大模型的图片审核服务-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/document_detail/2857796.html)

55. [分享#2: 借力国产AI大语言模型 仅需十几行代码实现违禁敏感词审查_违禁词 大模型-CSDN博客](https://blog.csdn.net/zzjlhlcd/article/details/146410801)

56. [调用ScanImage API实现图片内容审核-视觉智能开放平台-阿里云](https://help.aliyun.com/zh/viapi/developer-reference/api-f1y6cy)

57. [使用内容安全审核直播评论内容-在线部署-技术解决方案-阿里云](https://www.aliyun.com/solution/tech-solution-deploy/2713476)

58. [通过SDK与HTTPS原生调用接入文本审核增强版PLUS服务-内容安全-阿里云](https://help.aliyun.com/document_detail/433945.htm)

59. [ImageModeration接口的请求参数与返回参数-内容安全-阿里云](https://help.aliyun.com/zh/document_detail/2528742.html)

60. [图片审核增强版有哪些功能和如何计费-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/document_detail/467826.html#task-2275868)

61. [图文混合模态审核大模型服务-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/zh/document_detail/2974985.html)

62. [图像API文档常见问题-大模型服务平台百炼(Model Studio)-阿里云帮助中心](https://help.aliyun.com/zh/model-studio/developer-reference/image-faq)

63. [阿里云 2025 年 618 企业 新人 福利 ： AI 图像 识别 服务 0 元](https://www.iesdouyin.com/share/video/7518483359446748452)

64. [使用内容安全增强版进行AIGC文本风险检测-试用教程-试用中心-阿里云](https://developer.aliyun.com/adc/tutorial/2786625)

65. [阿里云人工智能实战第一枪:图片鉴黄节省90%费用-CSDN博客](https://blog.csdn.net/weixin_30662849/article/details/99368906)

66. [对图片进行内容安全风险检测-内容安全检测-对象存储-阿里云](https://help.aliyun.com/knowledge_detail/330964.html)

67. [能力展示-阿里云视觉智能开放平台](https://vision.aliyun.com/experience/detail)

68. [文本检测_开发文档_响应返回码_网易易盾](https://support.dun.163.com/documents/588434200783982592?docId=588930233091723264)

69. [云安全免费试用_验证码免费试用_内容安全试用_网易智企·易盾](https://dun.163.com/activity/free)

70. [图片检测_常见问题_接口常见问题_网易易盾](https://support.dun.163.com/qa/588434277524447232?docId=588514372075266048)

71. [当 AI 能 假装 专家 ， 连 ‘ 直播 带 货 ’ 都 成 骗局 。 平台 想 守住 真实 ， 得 靠 更 聪明 的 AI 。 网易 易 盾 CMA 审核 智能 体 ， 让 平台 的 内容 安全 跑 在 风险 前面 ～ 

# 网易 易 盾 # AI 生成 # 内容 安全 # AIGC # 内容 审核]([https://www.iesdouyin.com/share/video/7571336294224186639)](https://www.iesdouyin.com/share/video/7571336294224186639))

1. [内容合规必备:9 款高效敏感词内容检测工具对比测评 • Worktile社区](https://worktile.com/kb/p/3960275)

2. [内容安全必看:2026年11款主流音视频审核系统对比评测报告 • Worktile社区](https://worktile.com/kb/p/3960931)

3. [AI文章检测方法有哪些?2026最新指南_搜狐网](https://m.sohu.com/a/997607760_122630146/)

4. [2026 内容安全服务商排名:6 大主流风控检测系统深度对比_易盾_风险](https://m.sohu.com/a/998455918_122027489/)

5. [产品月报_开发文档_2025年12月产品月报_网易易盾](https://support.dun.163.com/documents/1035785077916278784?docId=1123685548406403072)

6. [文本检测_开发文档_文本接口_同步检测_单次同步检测_网易易盾](https://support.dun.163.com/documents/588434200783982592?docId=791131792583602176)

7. [CheckforAI和网易易盾-文本检测哪个好-有什么区别-优缺点-36氪企服点评](https://m.36dianping.com/vs/kh7l.html)

8. [到底 有 没有 人 管管 知网 啊 😬 。 咋 能 这么 贵 …](https://www.iesdouyin.com/share/video/7619593325113085888)

9. [网易易盾·文本识别-AI工具网](https://ai.youlu.com/tool/AAP20250329010000000005)

10. [搜索_网易易盾](https://support.test.dun.163.com/search?keyword=%E6%98%93%E7%9B%BE%E6%99%BA%E8%83%BD%E5%AE%A1%E6%A0%B8%E7%B3%BB%E7%BB%9F&t=1740316001879&pageNum=22&pageSize=20)

11. [AI文章检测方法有哪些?2026最新指南_搜狐网](https://m.sohu.com/a/997607760_122630146/)

12. [图片审核增强版介绍及计费说明](https://help.aliyun.com/zh/document_detail/467826.html)

13. [图文混合模态审核大模型服务-AI 安全护栏(AI Guardrails)-阿里云帮助中心](https://help.aliyun.com/zh/document_detail/2977152.html)

14. [智能审核费用计算方法与定价-视频直播-阿里云](https://help.aliyun.com/zh/live/product-overview/billing-of-automated-review)

15. [阿里云 2025 年 618 企业 新人 福利 ： AI 图像 识别 服务 0 元](https://www.iesdouyin.com/share/video/7518053195587882259)

16. [按量付费模式计费规则与价格-内容安全-阿里云](https://help.aliyun.com/zh/document_detail/2872704.html)

17. [使用内容安全增强版进行AIGC文本风险检测-试用教程-试用中心-阿里云](https://developer.aliyun.com/adc/tutorial/2786625)

18. [内容安全检测-试用教程-试用中心-阿里云](https://developer.aliyun.com/adc/tutorial/2668737)

19. [2026年论文降AI指南:从80%到5%，这些降AI率工具亲测高效!_实测_检测_处理](https://m.sohu.com/a/998031705_122651991/)

20. [Edge Functions](https://docs.weweb.io/workflows/actions/supabase/invoke-edge-function.html)

21. [Triggering tasks from Supabase Database Webhooks](https://trigger.dev/docs/guides/frameworks/supabase-edge-functions-database-webhooks)

22. [Summoning the Magical Powers of ChatGPT from your Supabase Edge Functions](https://github.com/burggraf/openai-supabase-edge-functions)

23. [Supabase：开源BaaS平台解析与 Firebase替代优势](https://www.iesdouyin.com/share/video/7568750312140360986)

24. [[supabase] Edge Functions 사용하기](https://velog.io/@yoosk5485/supabase-Edge-Functions-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0-i0s4kfyl)

25. [用Vercel AI SDK构建聊天机器人 - 汇智网](http://www.hubwiz.com/blog/build-chatbot-with-vercel-ai-sdk/)

26. [supabase/apps/docs/content/guides/functions/dependencies.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/functions/dependencies.mdx)

27. [让函数随时可用，详解PolarDB Supabase Edge Functions - 墨天轮](https://www.modb.pro/db/1955846061537374208)

28. [Edge Functions Architecture](https://supabase.com/docs/guides/functions/architecture)

29. [小说网站静态前端模板的评论审核机制](https://cq.zx.zbj.com/wenda/29865.html)

30. [部署自定义函数连接前后端逻辑-Edge Functions-云原生数据库 PolarDB-阿里云-云原生数据库 PolarDB(PolarDB)-阿里云帮助中心](https://help.aliyun.com/zh/polardb/polardb-for-postgresql/edge-functions-make-functions-readily-available)

31. [面试 场景 题 ： 海量 敏感 词 要求 10 毫秒 内 审核 完毕 ， 如何 快速 过滤 ？ # 程序员 # Java # 计算机 # Java 面试 # 春招](https://www.iesdouyin.com/share/video/7614085864825703743)

32. [内容审核的基本流程包括哪些环节?-腾讯云开发者社区](https://cloud.tencent.com/developer/techpedia/2286/19597)

33. [互联网信息内容审核流程指南.docx-原创力文档](https://m.book118.com/html/2025/1219/6212242015012032.shtm)

34. [交互内容审核与发布操作规程.docx-原创力文档](https://m.book118.com/html/2025/0415/8024024072007053.shtm)

35. [实时护航ai内容安全:大模型流式生成内容审核新范式](https://blog.csdn.net/gitblog_00103/article/details/154373563)

36. [Flutter for OpenHarmony 实战:Supabase — 跨平台后端服务首选_supabase开发flutter-CSDN博客](https://blog.csdn.net/cannonmonster01/article/details/158037418)

37. [Use Supabase with Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)

38. [《构建社交应用的安全结界:双框架对接审核API的底层逻辑与实践》-阿里云开发者社区](https://developer.aliyun.com/article/1663354)

39. [Java面试中敏感词过滤设计与高效实现方案解析](https://www.iesdouyin.com/share/video/7599598349326519588)

40. [Build a User Management App with Flutter](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)

41. [内容审核如何筛选有效内容?-腾讯云开发者社区-腾讯云](https://cloud.tencent.com/developer/ask/2166214/answer/2908170)

42. [互联网信息内容审核流程指南.docx-原创力文档](https://m.book118.com/html/2025/1219/6212242015012032.shtm)

43. [Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)

44. [2025新范式:用Next.js+Supabase实现企业级文件权限控制-CSDN博客](https://blog.csdn.net/gitblog_00597/article/details/152195329)

45. [Supabase + Next.jsで画像投稿アプリを最適化する（画像圧縮、ファイルサイズ制限、ファイルのアップロード数制限）](https://libproc.com/img-compress/)

46. [【GitHub开源项目实战】Supabase 开源实战解析:构建现代全栈应用的 Firebase 替代方案_superbase github-CSDN博客](https://blog.csdn.net/sinat_28461591/article/details/147963323)

47. [[최종 프로젝트 - React with typescript] Supabase(4)_Storage(이미지 여러장 넣고 미리보기)](https://velog.io/@liabin124/%EC%B5%9C%EC%A2%85-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8-React-with-typescript-Supabase4Storage%EC%9D%B4%EB%AF%B8%EC%A7%80-%EC%97%AC%EB%9F%AC%EC%9E%A5-%EB%84%A3%EA%B8%B0)

48. [Access Control](https://supabase.com/docs/guides/storage/access-control)

49. [campus-rallye-admin/supabase/buckets.md at main · DHBWLoerrach/campus-rallye-admin · GitHub](https://github.com/DHBWLoerrach/campus-rallye-admin/blob/main/supabase/buckets.md)

50. [Edge Functions](https://supabase.com/docs/guides/functions)

51. [大前端社交应用中 AI 驱动的内容审核与反垃圾信息机制_反垃圾审核-CSDN博客](https://blog.csdn.net/qq_28028013/article/details/151728616)

52. [Edge Functions Architecture](https://supabase.com/docs/guides/functions/architecture)

53. [Java面试中敏感词过滤设计与高效实现方案解析](https://www.iesdouyin.com/share/video/7599598349326519588)

54. [Routing](https://supabase.com/docs/guides/functions/http-methods)

55. [【GitHub开源项目实战】Supabase 开源实战解析:构建现代全栈应用的 Firebase 替代方案_superbase github-CSDN博客](https://blog.csdn.net/sinat_28461591/article/details/147963323)

56. [Supabase Edge Function](https://velog.io/@cheezstick/Supabase-Edge-Function)

57. [Supabase Edge Functions Function Output Truncated](https://drdroid.io/stack-diagnosis/supabase-edge-functions-function-output-truncated)

58. [@vettly/supabase](https://www.npmjs.com/package/@vettly/supabase)

59. [supabase/apps/docs/content/guides/functions/architecture.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/functions/architecture.mdx)

60. [【GitHub开源项目实战】Supabase 开源实战解析:构建现代全栈应用的 Firebase 替代方案_superbase github-CSDN博客](https://blog.csdn.net/sinat_28461591/article/details/147963323)

61. [Supabase：开源BaaS平台解析与 Firebase替代优势](https://www.iesdouyin.com/share/video/7568750312140360986)

62. [初探supabase: RLS、trigger、edge functionsupabase是什么? 一个BaaS，在po - 掘金](https://juejin.cn/post/7563473808994566198)

63. [使用 Supabase 实现轻量埋点监控基于 Supabase 构建一个轻量级、隐私友好的埋点分析系统，适合个人项目或小 - 掘金](https://juejin.cn/post/7581481178822754323)

64. [DIY Real-Time Polling App khóa truy cập với Supabase và Permit.io](https://hackernoon.com/lang/vi/diy-real-time-polling-app-locks-down-access-with-supabase-and-permitio%20%E1%BB%A9ng%20d%E1%BB%A5ng)

65. [supabase/apps/docs/content/guides/getting-started/tutorials/with-flutter.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/getting-started/tutorials/with-flutter.mdx)

66. [Supabase Flutter User Management](https://github.com/supabase/supabase/blob/master/examples/user-management/flutter-user-management/README.md)

67. [Flutter로 ChatGpt api 사용한 문제 생성 앱 만들기 #1 라이브러리 다운 및 Supabase DB 디자인](https://velog.io/@dandonedan/Flutter%EB%A1%9C-ChatGpt-api-%EC%82%AC%EC%9A%A9%ED%95%9C-%EB%AC%B8%EC%A0%9C-%EC%83%9D%EC%84%B1-%EC%95%B1-%EB%A7%8C%EB%93%A4%EA%B8%B0-1-%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC-%EB%8B%A4%EC%9A%B4-%EB%B0%8F-Supabase-DB-%EB%94%94%EC%9E%90%EC%9D%B8)

68. [开放能力 / 用户信息 / 获取头像昵称](https://developers.weixin.qq.com/miniprogram/dev/framework/open-ability/userProfile.html)

69. [Flutter for OpenHarmony 开发指南(六):个人中心开发-CSDN博客](https://blog.csdn.net/2501_94352565/article/details/157584327)

70. [Edge Functions](https://supabase.com/edge-functions)

71. [Triggering tasks from Supabase Database Webhooks](https://trigger.dev/docs/guides/frameworks/supabase-edge-functions-database-webhooks)

72. [Database trigger](https://www.answeroverflow.com/m/1417835201069056063)

73. [Supabase：开源BaaS平台解析与 Firebase替代优势](https://www.iesdouyin.com/share/video/7568750312140360986)

74. [Use case of DB trigger invoking one edge function calling another with authentication #21440](https://github.com/orgs/supabase/discussions/21440)

75. [Trigger anything from a database change using Supabase with Trigger.dev](https://trigger.dev/blog/supabase-and-trigger-dev)

76. [supabase/apps/docs/content/guides/functions/architecture.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/functions/architecture.mdx)

77. [How to send welcome emails with Supabase edge functions and database triggers](https://bejamas.io/hub/guides/send-emails-supabase-edge-functions-database-triggers)

78. [supabase/apps/docs/content/guides/getting-started/tutorials/with-flutter.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/getting-started/tutorials/with-flutter.mdx)

79. [如何在Flutter项目中使用supabase-flutter集成Supabase](http://bbs.itying.com/topic/6904e8654ed4930076ba06e7)

80. [React应用中用户头像更新与Supabase用户元数据管理](https://www.iesdouyin.com/share/video/7491303207486983433)

81. [Flutter for OpenHarmony 实战:Supabase — 跨平台后端服务首选_flutter_钛态-开源鸿蒙跨平台开发者社区](https://devpress.csdn.net/v1/article/detail/158037418)

82. [Supabase Flutter User Management](https://github.com/supabase/supabase/blob/master/examples/user-management/flutter-user-management/README.md)

83. [supabase_flutter 2.12.0](https://pub.dev/packages/supabase_flutter)

84. [在Flutter中如何集成Supabase](http://bbs.itying.com/topic/68ff9368e0a0e1004d86d75f)

85. [Edge Functions Architecture](https://supabase.com/docs/guides/functions/architecture)

86. [supabase/examples/edge-functions/supabase/functions/file-upload-storage/index.ts at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/examples/edge-functions/supabase/functions/file-upload-storage/index.ts)

87. [Edge Functions](https://supabase.com/edge-functions)

88. [使用Docker快速部署和运行Supabase教程](https://www.iesdouyin.com/share/video/7511364830603775268)

89. [supabase/apps/docs/content/guides/functions/storage-caching.mdx at master · supabase/supabase · GitHub](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/functions/storage-caching.mdx)

90. [【GitHub开源项目实战】Supabase 开源实战解析:构建现代全栈应用的 Firebase 替代方案_superbase github-CSDN博客](https://blog.csdn.net/sinat_28461591/article/details/147963323)

91. [Edge Functions](https://supabase.com/docs/guides/functions?ref=getdeploying)

92. [@alexwhitmore/storage-helpers](https://www.npmjs.com/package/@alexwhitmore/storage-helpers)

93. [rejected app - third-party content](https://developer.apple.com/forums/thread/114331)

94. [最新动态 - Apple Developer](https://developer.apple.com/cn/news/?id=3bwfq45y)

95. [iOS应用审核避坑指南:如何正确处理用户生成内容(UGC)以符合Apple审核1.2安全条款_SSSSSStacker-音视频技术专区](https://devpress.csdn.net/avi/698b74ae0a2f6a37c59116e3.html)

96. [苹果商店警告APP开发者的违规行为类型](https://www.iesdouyin.com/share/video/7483815673383111986)

97. [iOS App Store 提交被拒?请收好这份最新 ITMS 错误速查表-腾讯云开发者社区-腾讯云](https://cloud.tencent.com/developer/article/2523610)

98. [苹果App Store应用审核指南中文版:合规要求与常见拒绝原因详解 - CSDN文库](https://wenku.csdn.net/doc/4nmjq33m66)

99. [App 审核指南 - Apple 开发者](https://developer.apple.com/cn/app-store/review/guidelines/)

100. [如何建立UGC合规性内容审核体系_人人都是产品经理](http://m.toutiao.com/group/7584643545709986338/)

101. [iOS端APP提交审核被拒绝包含用户生成内容必须有举报和拉黑功能_we found in our review that your app includes user-CSDN博客](https://blog.csdn.net/xubingtao/article/details/117852903)

102. [工信部通报23款侵权APP并公布举报途径](https://www.iesdouyin.com/share/video/7539397186228866344)

103. [ios订阅支付 服务端 苹果商店订阅服务_deanyuancn的技术博客_51CTO博客](https://blog.51cto.com/u_13544/13878598)

104. [苹果开发者账号 5.6 差评政策详解，处理，预防差评警告最佳指南!_准则5.6-开发者行为准则 我们注意到您的应用程序似乎向用户或用户的联系人发送垃-CSDN博客](https://blog.csdn.net/2401_89843890/article/details/149808130)

105. [游戏被侵权了怎么办? 学会这些向苹果投诉的方法 |九四玩游戏代理加盟,页游平台源码,手游代理,手游联运平台_手游SDK_H5游戏代理](https://www.94wan.com/?ac=news&ct=index&id=3940&wap=1)

106. [App 审核指南 - Apple 开发者](https://developer.apple.com/app-store/review/guidelines/cn/)

107. [苹果应用商店AppStore审核中文指南 分类: ios相关 ...-CSDN博客](https://blog.csdn.net/weixin_33895016/article/details/93550930)

108. [App Store:AppStore审核指南与合规要求.docx-原创力文档](https://m.book118.com/html/2025/0903/7115125152010153.shtm)

109. [App Store审核六次被拒经验总结：四大避坑指南解析](https://www.iesdouyin.com/share/video/7548419111300500771)

110. [苹果App Store应用审核指南中文版:合规要求与常见拒绝原因详解 - CSDN文库](https://wenku.csdn.net/doc/4nmjq33m66)

111. [App Review Guidelines](https://developer-mdn.apple.com/app-store/review/guidelines/)

112. [App Store上架完整流程与注意事项详解本文详细介绍了iOS应用上架App Store的完整流程，包括证书配置、元数 - 掘金](https://juejin.cn/post/7584273076645691398)

113. [app上架app store审核指南 - AppleByMe-专业代上架苹果市场服务系统](https://www.applebyme.cn/Article/show/15800)

114. [App 审核 - 分发 - Apple 开发者](https://developer.apple.com/cn/app-store/review/rejections/)

115. [app审核](https://developer.apple.com/app-store/review/guidelines/cn/)

116. [图文详解丨iOS App上架全流程及审核避坑指南_mob64ca13f50747的技术博客_51CTO博客](https://blog.51cto.com/u_16213570/14517565)

117. [iOS App提交审核前需注意的关键审核事项解析](https://www.iesdouyin.com/share/video/7542835862359346475)

118. [App Store上架完整流程与注意事项详解本文详细介绍了iOS应用上架App Store的完整流程，包括证书配置、元数 - 掘金](https://juejin.cn/post/7584273076645691398)

119. [iOS上架那些事:从准备到过审的全攻略 对于每一位移动开发者而言，iOS应用上架App Store绝非简单的"提交即可 - 掘金](https://juejin.cn/post/7595030559563907123)

120. [iOS App 上架审核全流程深度解析，规则理解、风险管理与团队协同策略-CSDN博客](https://blog.csdn.net/2501_91590906/article/details/155313710)

121. [完整教程:苹果应用商店上架的系统逻辑，从产品开发到使用开心上架上架ipa交付审核流程](https://blog.51cto.com/u_15469972/14459978)

122. [App 审核指南 - Apple 开发者](https://developer.apple.com/cn/app-store/review/guidelines/)

123. [小米应用商店新增人工智能生成合成内容标识_小米应用商店上架app,人工智能生成合成服务需要填写什么资料,该怎么写啊-CSDN博客](https://blog.csdn.net/qq_67796576/article/details/153051953)

124. [关于印发《人工智能生成合成内容标识办法》的通知-新华网](http://www.news.cn/politics/20250314/75107e1e6566404f8471559a8fb34158/c.html)

125. [四部门联合规范AI合成内容标识管理](https://www.iesdouyin.com/share/video/7546152669687237931)

126. [China’s New Rules for Labeling AI-Generated Content Commences Operation](https://mmlcgroup.com/china-ai-labelling-rules/)

127. [国家互联网信息办公室 中华人民共和国国家发展和改革委员会 中华人民共和国教育部 中华人民共和国科学技术部 中华人民共和国工业和信息化部 中华人民共和国公安部 国家广播电视总局令(第15号) 生成式人工智能服务管理暂行办法__2023年第24号国务院公报_中国政府网](http://www.gov.cn/govweb/gongbao/2023/issue_10666/202308/content_6900864.html)

128. [特殊品类标准 | 小米澎湃OS开发者平台](https://dev.mi.com/distribute/doc/details?pId=1509)

129. [从过审到推荐，一文搞懂上架流程:2025苹果AppStore全流程实战手册-腾讯新闻](https://news.qq.com/rain/a/20250821A09EEU00)

130. [我把 App 成功上架到 App Store 的完整心法:从零到审核通过的深度技术实战_苹果商店上架app通过率-CSDN博客](https://blog.csdn.net/jiandan1127/article/details/155307976)

131. [ios上架app资制需要什么? - AppleByMe-专业代上架苹果市场服务系统](https://www.applebyme.cn/article/show/12570)

132. [2025年苹果开发者App Store上架流程与合规指南](https://www.iesdouyin.com/share/video/7504485634222296355)

133. [The Complete Guide to Content Review in China](https://appinchina.co/blog/the-complete-guide-to-content-review-in-china/)

134. [应用分发资质与审核规范_当下软件开放平台](https://pt.downxia.com/index/pt_help?id=9)

135. [安卓应用下载(Android App Store)系统商城上架要求有那些注意事项?一、应用资质与合规性要求**** 1. - 掘金](https://juejin.cn/post/7573525927792459802)

136. [适用于中国大陆的Apple广告指南](https://ads.apple.com/v/help/a/docs/apple-advertising-guidelines-for-mainland-china.pdf)

137. [App 审核 - 分发 - Apple 开发者](https://developer.apple.com/cn/distribute/app-review/)

138. [wetest导读](https://testerhome.com/topics/7188/show_wechat)

139. [app上架需要提供采购证明吗? - AppleByMe-专业代上架苹果市场服务系统](https://www.applebyme.cn/article/show/14202)

140. [2025年苹果开发者App Store上架流程与合规指南](https://www.iesdouyin.com/share/video/7504485634222296355)

141. [从过审到推荐，一文搞懂上架流程:2025苹果AppStore全流程实战手册-腾讯新闻](https://news.qq.com/rain/a/20250821A09EEU00)

142. [苹果app开发者后台会员怎么续订_敲黑板!关于开发者提交审核的必备知识点!...-CSDN博客](https://blog.csdn.net/weixin_34653299/article/details/112771193)

143. [ios上架app资制需要什么?-互联网资讯](https://app.applebyme.cn/cloud/wwwinfo/62272.html)

144. [应用资质审核要求-审核政策-应用市场 - 华为HarmonyOS开发者](https://developer.huawei.com/consumer/cn/doc/app/80301)

145. [앱 심사 지침](https://developer.apple.com/kr/app-store/review/guidelines/)

146. [国家互联网信息办公室 中华人民共和国国家发展和改革委员会 中华人民共和国教育部 中华人民共和国科学技术部 中华人民共和国工业和信息化部 中华人民共和国公安部 国家广播电视总局令(第15号) 生成式人工智能服务管理暂行办法__2023年第24号国务院公报_中国政府网](http://www.gov.cn/govweb/gongbao/2023/issue_10666/202308/content_6900864.html)

147. [“ 标识 办法 ” 明确 所有 AI 生成 的 文字 、 图片 、 视频 等 内容 都 要 “ 亮明 身份 ” 。 （ 来源 ： 央视网 ）](https://www.iesdouyin.com/share/video/7547245598924148022)

148. [特殊品类标准 | 小米澎湃OS开发者平台](https://dev.mi.com/distribute/doc/details?pId=1509)

149. [生成式人工智能服务管理暂行办法](https://www.miit.gov.cn/zcfg/qtl/art/2023/art_f4e8f71ae1dc43b0980b962907b7738f.html)

150. [应用审核被拒:提示应用缺少AI文本生成模块的资质证明文件，不符合相关法律法规要求。 | 华为开发者问答](https://developer.huawei.com/consumer/cn/forum/topic/0203189879756706004)

151. [关于印发《人工智能生成合成内容标识办法》的通知_国务院部门文件_中国政府网](https://www.gov.cn/zhengce/zhengceku/202503/content_7014286.htm)

152. [App 审核指南 - Apple 开发者](https://developer.apple.com/cn/app-store/review/guidelines/)

153. [iOS应用发布紧急避雷:这些审核规则更新你必须立刻知道-CSDN博客](https://blog.csdn.net/VarFlow/article/details/153326727)

154. [2025年苹果开发者App Store上架流程与合规指南](https://www.iesdouyin.com/share/video/7504485634222296355)

155. [如何建立UGC合规性内容审核体系_人人都是产品经理](http://m.toutiao.com/group/7584643545709986338/)

156. [App 审核 - 分发 - Apple 开发者](https://developer.apple.com/cn/distribute/app-review/)

157. [人机协同发力!UGC论坛内容审核，筑牢iOS合规底线_要求_违规_用户](https://m.sohu.com/a/967210029_122575987/)

158. [AI智能问答系统内容审核成本优化实战:从费用计算到效率提升_音视频小白-音视频技术专区](https://devpress.csdn.net/avi/698231c8a16c6648a9871b52.html)

159. [图片审核增强版有哪些功能和如何计费-内容安全(Content Moderation)-阿里云帮助中心](https://help.aliyun.com/zh/document_detail/467826.html)

160. [Content Safety in Foundry Control Plane - Pricing | Microsoft Azure](https://azure.microsoft.com/zh-cn/pricing/details/cognitive-services/content-safety/)

161. [一亿 活 的 豆包 为什么 可以 免费 使用 ， 它 烧 得 起 算 力 吗 ？ 1 、 分析 一下 它 的 用户 结构 ， 每个 用户 每天 使用 多少 token ； 2 、 分析 一下 每个 token 多少 钱 3 、 一 年 豆包 烧 多少 钱 4 、 豆包 这样 聊天 机器人 和 小龙虾 这样 干活 的 智能 体 token 消耗 对比 。 # 豆包 # 算 力 # 小龙虾 # 金融 ](https://www.iesdouyin.com/share/video/7619876345929756297)

162. [价格 | 内容审核 - 七牛云](https://www.qiniu.com/prices/censor)

163. [对象存储 内容审核费用_腾讯云](https://cloud.tencent.cn/document/product/436/58965)

164. [内容审核API调用计费规则_图普科技](https://shenhe.tuputech.com/API)

165. [Server 数美内容审核 计费说明 - 开发者中心 - ZEGO即构科技](https://doc-zh.zego.im/article/18681)

166. [Predictable pricing,](https://supabase.com/pricing)

167. [Supabase vs AWS: Feature and Pricing Comparison (2026)](https://www.bytebase.com/blog/supabase-vs-aws-pricing/)

168. [Supabase 计费说明 | Supabase 文档中文版](https://supabase.doczh.com/docs/guides/platform/billing-on-supabase)

169. [2025年低成本数据库服务对比与性价比推荐](https://www.iesdouyin.com/share/video/7598448253935340863)

170. [supabasepricing2025:free,pro&enterprisecosts|metacto](https://www.metacto.com/blogs/the-true-cost-of-supabase-a-comprehensive-guide-to-pricing-integration-and-maintenance)

171. [Supabase | i For AI - 人工智能AI工具，一站式导航](https://iforai.com/sites/4402.html)

172. [Supabase 适用场景全解析:从原型到生产的落地指南_supabase 使用场景-CSDN博客](https://blog.csdn.net/qq_44608856/article/details/154690601)

173. [Storage Optimizations](https://supabase.com/docs/guides/storage/production/scaling)

174. [《构建社交应用的安全结界:双框架对接审核API的底层逻辑与实践》-阿里云开发者社区](https://developer.aliyun.com/article/1663354)

175. [在Flutter中如何集成Supabase](http://bbs.itying.com/topic/68ff9368e0a0e1004d86d75f)

176. [如何在Flutter项目中使用supabase-flutter集成Supabase](http://bbs.itying.com/topic/6904e8654ed4930076ba06e7)

177. [API接口对接全流程解析](https://www.iesdouyin.com/share/video/7323489716173540662)

178. [FlutterFlow](https://supabase.com/partners/integrations/flutterflow)

179. [Integrating Flutter with Supabase: A Comprehensive Guide](https://hussainmustafa.com/integrating-flutter-with-supabase-a-comprehensive-guide/)

180. [supabase_flutter 2.12.0](https://pub.dev/packages/supabase_flutter)

181. [Integrating Third-Party APIs in Flutter App](https://innoventixsolutions.com/integrating-third-party-apis-in-your-flutter-app/)

182. [《构建社交应用的安全结界:双框架对接审核API的底层逻辑与实践》随着用户生成内容激增，社交应用面临虚假信息、暴力言论等挑 - 掘金](https://juejin.cn/post/7503756869786763300)

183. [Flutter Client Library](https://supabase.com/docs/reference/dart/removechannel)

184. [api测试面临的主要挑战是什么?](https://blog.csdn.net/weixin_45422672/article/details/145835837)

185. [接口测试缺陷排查方法论与四层深度验证法解析](https://www.iesdouyin.com/share/video/7493752809809087778)

186. [程序员一定要懂的API接口测试要点API接口测试的要点主要包括以下几个方面: 1. 接口文档分析 请求类型:明确接口是G - 掘金](https://juejin.cn/post/7407004271328297012)

187. [Flutter 앱에 Supabase 인증 시스템 구현하기( 첫 Supabase)](https://velog.io/@dlworua/Flutter-%EC%95%B1%EC%97%90-Supabase-%EC%9D%B8%EC%A6%9D-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%ED%98%84%ED%95%98%EA%B8%B0-%EC%B2%AB-Supabase)

188. [《构建社交应用的安全结界:双框架对接审核API的底层逻辑与实践》-阿里云开发者社区](https://developer.aliyun.com/article/1663354)

189. [Flutterflow Stripe Integration with Supabase](https://www.flutterflowdevs.com/blog/flutterflow-stripe-integration-with-supabase)

190. [Edge Functions](https://supabase.com/docs/guides/functions)

191. [Supabase：开源BaaS平台解析与 Firebase替代优势](https://www.iesdouyin.com/share/video/7568750312140360986)

192. [【GitHub开源项目实战】Supabase 开源实战解析:构建现代全栈应用的 Firebase 替代方案_superbase github-CSDN博客](https://blog.csdn.net/sinat_28461591/article/details/147963323)

193. [Flutter后端服务调用插件supabase_functions的使用](http://bbs.itying.com/topic/67b77f7036bb8501316f5482)

194. [Integrating With Supabase Auth](https://supabase.com/docs/guides/functions/auth-legacy-jwt)

195. [Full-stack Dart with Flutter, Supabase and Dart Edge](https://dartling.dev/full-stack-dart-with-flutter-supabase-and-dart-edge)

196. [内容审核API调用计费规则_图普科技](https://shenhe.tuputech.com/API)

197. [AI智能问答内容审核费用成本分析:从技术选型到成本优化实战_音视频小白-音视频技术专区](https://devpress.csdn.net/avi/698231c97c1d88441d919c5a.html)

198. [Server 数美内容审核 计费说明 - 开发者中心 - ZEGO即构科技](https://doc-zh.zego.im/article/18681)

199. [内容审核各项能力计费与价格-视觉智能开放平台-阿里云](https://help.aliyun.com:443/zh/viapi/product-overview/billing-is-introduced-7)

200. [AWS内容审核API实战:如何用AI辅助开发提升审核效率与准确性_Hello亲431-音视频技术专区](https://devpress.csdn.net/avi/699359cb0a2f6a37c5921a89.html)

201. [内容审核计费说明(海外版) | IM 文档](https://doc.easemob.com/value-added/moderation/moderation_billing_overseas.html)

202. [API 网关 共享实例计费_腾讯云](https://cloud.tencent.cn/document/product/628/39300)
> （注：文档部分内容可能由 AI 生成）