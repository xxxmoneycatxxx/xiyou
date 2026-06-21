# 幻想西游

基于 PHP + MySQL 的文字 MUD 网游，仿《梦幻西游》玩法深度改编。源码源自《小轩西游》，已全面兼容 PHP 8.2。

---

## 运行环境

- PHP 8.2（需 `pdo_mysql` `curl` `bcmath` `mbstring` `opcache` 扩展）
- MySQL 5.7+（MariaDB 亦可，默认 InnoDB）
- Apache（需 `mod_rewrite`）
- 无需 Composer

---

## 快速部署

### Docker（推荐）

```powershell
# Windows PowerShell
.\docker_deploy.ps1                          # 默认 http://localhost:8080
.\docker_deploy.ps1 -AppUrl http://你的IP:8080 -MysqlPassword 自定义密码

# 其他系统 / 手动启动
docker compose -f docker/docker-compose.yml up -d --build
```

首次运行会自动完成：镜像构建 → MySQL + Apache 启动 → 数据库导入 → 目录权限配置。访问 `http://localhost:8080`（或你指定的地址）即可。

> **注意事项**：
> - 确保 `config/config.php` 和 `fqxy/config/config.php` 中 `urls` / `xy_url` / `jy_url` 的 IP:端口**完全一致**，否则选服后会因跨服认证 URL 不匹配被踢回登录页。
> - `docker_deploy.ps1` 需要 UTF-8 with BOM 编码，如果出现乱码错误，用 VS Code / Notepad++ 另存为 UTF-8 with BOM。

常用管理命令：

```bash
docker compose -f docker/docker-compose.yml -p xiyou restart app  # 重启游戏服
docker compose -f docker/docker-compose.yml -p xiyou down          # 停止所有服务
docker compose -f docker/docker-compose.yml -p xiyou logs -f app   # 查看日志
docker exec -it xiyou-mysql mysql -uroot -proot xxjyuser           # 直连数据库
```

---

### 手动部署

<details>
<summary>展开传统手动部署步骤</summary>

#### 1. 数据库

```sql
CREATE DATABASE xxjyuser DEFAULT CHARSET utf8mb4;
CREATE DATABASE xyy DEFAULT CHARSET utf8mb4;
```

```bash
mysql -u root -p xxjyuser < data/xxjyuser.sql
mysql -u root -p xyy < data/xyy.sql
```

#### 2. 配置文件

```bash
cp config/config_example.php config/config.php
cp fqxy/config/config_example.php fqxy/config/config.php
```

`config/config.php` — 家园（账号总站）：

```php
$config['jy_url'] = 'http://你的域名';
$config['urls'] = [
    ['qy' => 1, 'url' => 'http://你的域名', 'name' => '傲来国', 'status' => 1],
];
$config['mysql'] = ['host' => 'localhost', 'user' => 'root', 'password' => 'root', 'database' => 'xxjyuser'];
$config['debug'] => false;
```

`fqxy/config/config.php` — 分区（游戏世界）：

```php
$config['jy_url'] = 'http://你的域名';       // 指向家园
$config['xy_url'] = 'http://你的域名';       // 本分区地址
$config['mysql'] = ['host' => 'localhost', 'user' => 'root', 'password' => 'root', 'database' => 'xyy'];
$config['debug'] => false;
$config['edit_map'] => false;              // 切勿开启
```

#### 3. 访问

设置 Web 根目录到项目根路径，通过域名访问。首页自动重定向到登录页。

</details>

---

## 架构深度解析

### 整体架构：家园 + 多分区

```
┌───────────────┐
│  xxjyuser 库   │  总站数据库：只存账号密码和认证令牌
└──────┬────────┘
       │
┌──────┴────────┐    家园（xxjy/）——用户注册、登录、改密
│   家园 (总站)   │    不承载游戏逻辑，只做身份管理
└──────┬────────┘
       │ CURL 跨服认证（token + 分区号 + 来源 URL 三重校验）
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   分区 1      │     │   分区 2      │     │   分区 N      │
│  (xyy 库)     │     │  (xyy 库)     │     │  (xyy 库)     │
└──────────────┘     └──────────────┘     └──────────────┘
     fqxy/                fqxy/               fqxy/
```

- **家园**（`xxjy/` + `config/`）：维护 `xxjyuser` 库中唯一的 `o_user_list` 表，存储账号、密码哈希、认证 token（`ma` 字段）。作为"用户中心"，不参与游戏逻辑。
- **分区**（`fqxy/`）：每个分区是独立的游戏世界，拥有完整的 `xyy` 库（74 张表）和独立的 INI 文件缓存。通过 `config.php` 的 `urls` 数组可配置无限个分区，共享同一套家园认证。

> 架构上，这是一个典型的 **中心化认证 + 分布式游戏服** 设计，只不过"分布式"是指手动配置多个独立部署的游戏副本。

---

### 玩家登录全链路

```
1. index.php → 302 → xxjy/index.php（登录表单）
                         │
2. POST username + password → md5(pwd + 'ALL_PS') 比对 o_user_list.password
                         │
3. 生成 32 位随机 token → 写入 o_user_list.ma → 302 → xywap.php?uid=X&token=Y
                         │
4. 玩家选择分区 → 跳转 fqxy/xyy.php?uid=X&token=Y&qy=分区号
                         │
5. fqxy/xyy.php：
   a. CURL POST uid|token|本区URL|qy → 家园 /sql/xxjyCurl.php 验证
      - 家园端比对 token(hash_equals)、校验来源 URL、校验分区号
      - 返回 2 表示通过
   b. sqid = (uid+10000000)_qy → 查询/创建本地 o_user_list → 得到 fquid
   c. wjid = fquid + 10000000（游戏内唯一玩家 ID）
   d. 初始化 INI 缓存，写入 session
   e. 302 → xy.php（游戏主循环）
```

> 关键设计：玩家 ID = `10000000 + 分区内UID`，保证跨区分隔。sqid 通过 `社区ID_分区号` 格式绑定，同一社区账号在不同分区有独立角色。

---

### 游戏主循环：cmd 命令分发机制

`xy.php` 是整个游戏的**唯一交互入口**。玩家的每一次点击都是一个 GET 请求到 `xy.php?cmd=N`。

#### 路由表（手工分段）

> **使用方式**：在浏览器地址栏找到 `cmd=数字`，在下表搜索该数字即可定位到对应模板文件。
>
> 路由规则：`xy.php` 根据 cmd 范围分发到 7 个路由文件，每个文件内再通过 `if/elseif` 链映射到具体模板。

| 路由文件 | cmd 范围 | 领域 |
|----------|----------|------|
| `xy01.php` | 1–100 | 核心：首页/状态/技能/背包/装备/副本/地图移动 |
| `xy02.php` | 101–200 | 社交：宠物/住宅/国家/攻城/好友/组队 |
| `xy03.php` | 201–300 | 系统：设置/挂售/仓库/结婚/称号/开局 |
| `xy04.php` | 301–400 | 战斗：PK/排行榜/宠物/充值/死亡复活 |
| `xy05.php` | 401–500 | 修炼：挑战/修炼/拍卖/称号/娱乐活动 |
| `xy06.php` | 501–600 | 红包：红包/财神/赠送/占星/星盘 + fallback |
| `xy07.php` | 601–20000 | 活动：节日/VIP/农场/武道会/国家商城 + fallback |

每个 `xy0X.php` 内部是一个巨大的 `if/elseif` 链，将 `cmdd`（当前页面 ID）映射到 `template/xyNNN.php` 模板。这是一个**手工维护的静态路由表**，700+ 个页面靠 7 个文件分段管理。

##### 一、核心页面 (cmd 1~100) → xy01.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 1 | 首页/登录 | template/xy001.php |
| 2 | 游戏主页（地图+玩法菜单） | template/xy002.php |
| 3 | 游戏上走 | template/xy003.php |
| 4 | 游戏下走 | template/xy004.php |
| 5 | 游戏左走 | template/xy005.php |
| 6 | 游戏右走 | template/xy006.php |
| 7 | NPC 交互页面 | template/xy007.php |
| 8 | 查看地图 | template/xy008.php |
| 9 | 返回游戏 | template/xy009.php |
| 10 | 战斗页面 | template/xy010.php |
| 11 | 状态面板 | template/xy011.php |
| 12 | 技能模板 | template/xy012.php |
| 13 | 技能详情 | template/xy013.php |
| 14 | 技能设置（一） | template/xy014.php |
| 15 | 技能设置（二） | template/xy015.php |
| 16 | 技能设置（三） | template/xy016.php |
| 17 | 技能设置（四） | template/xy017.php |
| 19 | 查看 | template/xy019.php |
| 20 | 传送 | template/xy020.php |
| 21 | 聊天（世界） | template/xy021.php |
| 22 | 聊天（组队） | template/xy022.php |
| 23 | 聊天（国家） | template/xy023.php |
| 24 | 发送私聊 | template/xy024.php |
| 25 | 私聊消息 | template/xy025.php |
| 27 | 书卷（背包） | template/xy027.php |
| 28 | 材料（背包） | template/xy028.php |
| 29 | 装备（背包） | template/xy029.php |
| 30 | 商城（背包） | template/xy030.php |
| 31 | 丹药（背包） | template/xy031.php |
| 32 | 任务（背包） | template/xy032.php |
| 33 | 农场（背包） | template/xy033.php |
| 34 | 宝箱（背包） | template/xy034.php |
| 35 | 其他（背包） | template/xy035.php |
| 36 | 查看物品信息 | template/xy036.php |
| 37 | 使用物品 | template/xy037.php |
| 38 | 下一页 | template/xy038.php |
| 39 | 上一页 | template/xy039.php |
| 40 | 首页（翻页） | template/xy040.php |
| 41 | 末页（翻页） | template/xy041.php |
| 43 | 任务界面 | template/xy043.php |
| 44 | 任务界面（列表） | template/xy044.php |
| 45 | 主线任务 | template/xy045.php |
| 46 | 支线任务 | template/xy046.php |
| 47 | 日常任务 | template/xy047.php |
| 48 | 活动任务 | template/xy048.php |
| 49 | 任务详细情况 | template/xy049.php |
| 50 | 经验条 | template/xy050.php |
| 51 | 修炼经验条 | template/xy051.php |
| 52 | 修炼经验开关 | template/xy052.php |
| 53 | 商城一页 | template/xy053.php |
| 54 | 商城二页 | template/xy054.php |
| 55 | 商城信息 | template/xy055.php |
| 56 | 声望 | template/xy056.php |
| 57 | 排行榜（总入口） | template/xy057.php |
| 60 | 祝福状态 | template/xy060.php |
| 62 | 背包查看装备信息 | template/xy062.php |
| 69 | 装备打孔 | template/xy069.php |
| 71 | 宝石 | template/xy071.php |
| 73 | 宝石镶嵌 | template/xy073.php |
| 74 | 宝石镶嵌（确认） | template/xy074.php |
| 75 | 宝石摘除 | template/xy075.php |
| 77 | 装备材料升星 | template/xy077.php |
| 79 | 装备升星符升星 | template/xy079.php |
| 80 | 装备上的宝石信息 | template/xy080.php |
| 81 | 自己查看装备 | template/xy081.php |
| 82 | 穿装备 | template/xy082.php |
| 83 | 查看身上装备信息 | template/xy083.php |
| 84 | 卸下装备 | template/xy084.php |
| 85 | 副本激活 | template/xy085.php |
| 86 | 日常任务详情 | template/xy086.php |
| 87 | 副本完成 | template/xy087.php |
| 88 | 副本已激活 | template/xy088.php |
| 90 | 装备升级 | template/xy090.php |
| 91 | 打造装备 | template/xy091.php |
| 92 | 更多玩家 | template/xy092.php |
| 93 | 查看玩家 | template/xy093.php |
| 94 | 看装 | template/xy094.php |
| 95 | 看装备 | template/xy095.php |
| 96 | 看状态 | template/xy096.php |
| 97 | 私聊 | template/xy097.php |
| 98 | 组队（邀请） | template/xy098.php |
| 99 | 交易 | template/xy099.php |
| 100 | 加好友 | template/xy100.php |

##### 二、社交/宠物/住宅/国家 (cmd 101~200) → xy02.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 101 | 宠物交易 | template/xy101.php |
| 102 | 住宅交易 | template/xy102.php |
| 103 | 邀请入国 | template/xy103.php |
| 104 | 拉入黑名单 | template/xy104.php |
| 105 | 看宠物 | template/xy105.php |
| 106 | 看宝宝 | template/xy106.php |
| 107 | NPC 信息首页（指引/攻略） | template/xy107.php |
| 108 | 聊天回复 | template/xy108.php |
| 109 | 组队接受 | template/xy109.php |
| 110 | 组队拒绝 | template/xy110.php |
| 111 | 队伍面板 | template/xy111.php |
| 112 | 踢出队伍 | template/xy112.php |
| 113 | 解散队伍/退出队伍 | template/xy113.php |
| 114 | 好友列表 | template/xy114.php |
| 115 | 删除好友 | template/xy115.php |
| 116 | 加入黑名单 | template/xy116.php |
| 117 | 删除黑名单 | template/xy117.php |
| 122 | 买东西 | template/xy122.php |
| 123 | 腾云符 | template/xy123.php |
| 124 | 丢弃物品 | template/xy124.php |
| 126 | 丢弃全部 | template/xy126.php |
| 127 | 丢弃装备 | template/xy127.php |
| 130 | 世界 Boss 战斗 | template/xy130.php |
| 151 | 购买房子 | template/xy151.php |
| 152 | 出售房子 | template/xy152.php |
| 153 | 查看官宅 | template/xy153.php |
| 154 | 购买官宅 | template/xy154.php |
| 155 | 进入住宅 | template/xy155.php |
| 156 | 进入住宅（确认） | template/xy156.php |
| 157 | 玩家住宅家具模板 | template/xy157.php |
| 158 | 住宅家具信息 | template/xy158.php |
| 159 | 住宅家具打造 | template/xy159.php |
| 160 | 查看家具摆放 | template/xy160.php |
| 161 | 查看家具信息 | template/xy161.php |
| 162 | 家具摆放 | template/xy162.php |
| 163 | 家具取消摆放 | template/xy163.php |
| 164 | 家具升级 | template/xy164.php |
| 165 | 住宅改名 | template/xy165.php |
| 166 | 邀请好友进入住宅 | template/xy166.php |
| 167 | 邀请好友进入住宅（发） | template/xy167.php |
| 168 | 同意邀请看房子 | template/xy168.php |
| 169 | 房子踢人 | template/xy169.php |
| 170 | 房子踢人（请他离开） | template/xy170.php |
| 171 | 建立国家 | template/xy171.php |
| 172 | 国家面板 | template/xy172.php |
| 173 | 二次确认解散国家 | template/xy173.php |
| 175 | 国家成员列表 | template/xy175.php |
| 176 | 任命国家官员 | template/xy176.php |
| 177 | 任命国家官员（确认） | template/xy177.php |
| 178 | 任命国家官员（执行） | template/xy178.php |
| 179 | 罢免国家官员 | template/xy179.php |
| 180 | 接受入国邀请 | template/xy180.php |
| 181 | 拒绝入国邀请 | template/xy181.php |
| 182 | 退出国家二次确认 | template/xy182.php |
| 183 | 拒绝邀请看房子 | template/xy183.php |
| 184 | 踢出国家成员二次确认 | template/xy184.php |
| 185 | 国家捐献 | template/xy185.php |
| 186 | 国家商城 | template/xy186.php |
| 187 | 攻城管理 | template/xy187.php |
| 188 | 攻城说明 | template/xy188.php |
| 189 | 攻城地图 | template/xy189.php |
| 190 | 攻城占领信息 | template/xy190.php |
| 191 | 攻城报名 | template/xy191.php |
| 192 | 报名信息 | template/xy192.php |
| 193 | 国家权杖 | template/xy193.php |
| 194 | 国战大门神兽信息 | template/xy194.php |
| 195 | 查询国战信息 | template/xy195.php |

##### 三、系统设置/挂售/仓库/开局 (cmd 203~299) → xy03.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 203 | 游戏设置 | template/xy203.php |
| 204 | 显示设置 | template/xy204.php |
| 205 | 设置开关 | template/xy205.php |
| 206 | 国战排行榜 | template/xy206.php |
| 212 | 求婚 | template/xy212.php |
| 213 | 玄铁令兑换 | template/xy213.php |
| 214 | 同意结婚 | template/xy214.php |
| 215 | 拒绝结婚 | template/xy215.php |
| 216 | 离婚 | template/xy216.php |
| 218 | 上架挂售物品 | template/xy218.php |
| 219 | 挂售物品列表 | template/xy219.php |
| 220 | 挂售物品信息 | template/xy220.php |
| 221 | 下架挂售物品 | template/xy221.php |
| 222 | 查看对方挂售物品 | template/xy222.php |
| 223 | 查看对方挂售物品信息 | template/xy223.php |
| 224 | 购买对方挂售物品 | template/xy224.php |
| 225 | 挂售物品分类 | template/xy225.php |
| 226 | 查看对方挂售物分类 | template/xy226.php |
| 228 | 上架挂售装备 | template/xy228.php |
| 229 | 挂售装备分类 | template/xy229.php |
| 230 | 挂售装备信息 | template/xy230.php |
| 231 | 下架挂售装备 | template/xy231.php |
| 232 | 查看对方挂售装备 | template/xy232.php |
| 233 | 查看对方挂售装备信息 | template/xy233.php |
| 234 | 购买对方挂售装备 | template/xy234.php |
| 235 | 上架挂售宝石 | template/xy235.php |
| 236 | 挂售宝石列表 | template/xy236.php |
| 237 | 查看挂售宝石信息 | template/xy237.php |
| 238 | 下架挂售宝石 | template/xy238.php |
| 239 | 查看对方挂售宝石 | template/xy239.php |
| 240 | 查看对方挂售宝石信息 | template/xy240.php |
| 241 | 购买对方挂售宝石 | template/xy241.php |
| 242 | 丢弃宝石 | template/xy242.php |
| 243 | 丢弃宝石（确认） | template/xy243.php |
| 245 | 结婚婚事 | template/xy245.php |
| 246 | 买东西 | template/xy246.php |
| 247 | 快捷键设置 | template/xy247.php |
| 248 | 药品恢复 | template/xy248.php |
| 249 | 宠物捕捉 | template/xy249.php |
| 251 | 管理称号 | template/xy251.php |
| 252 | 称号详情 | template/xy252.php |
| 253 | 称号显示开关 | template/xy253.php |
| 257 | 存取银两 | template/xy257.php |
| 258 | 存银两 | template/xy258.php |
| 259 | 取银两 | template/xy259.php |
| 260 | 仓库 | template/xy260.php |
| 261 | 仓库书卷存 | template/xy261.php |
| 262 | 仓库材料存 | template/xy262.php |
| 263 | 仓库装备存 | template/xy263.php |
| 264 | 仓库商城存 | template/xy264.php |
| 265 | 仓库丹药存 | template/xy265.php |
| 266 | 仓库任务存 | template/xy266.php |
| 267 | 仓库农场存 | template/xy267.php |
| 268 | 仓库宝箱存 | template/xy268.php |
| 269 | 仓库其他存 | template/xy269.php |
| 270 | 仓库查看 | template/xy270.php |
| 271 | 仓库物品存入 | template/xy271.php |
| 272 | 仓库查看装备 | template/xy272.php |
| 273 | 仓库查看宝石 | template/xy273.php |
| 274 | 仓库物品存入全部 | template/xy274.php |
| 275 | 仓库装备存入 | template/xy275.php |
| 276 | 仓库宝石存入 | template/xy276.php |
| 277 | 仓库宝石存入全部 | template/xy277.php |
| 278 | 仓库书卷取 | template/xy278.php |
| 279 | 仓库材料取 | template/xy279.php |
| 280 | 仓库装备取 | template/xy280.php |
| 281 | 仓库商城取 | template/xy281.php |
| 282 | 仓库丹药取 | template/xy282.php |
| 283 | 仓库任务取 | template/xy283.php |
| 284 | 仓库农场取 | template/xy284.php |
| 285 | 仓库宝箱取 | template/xy285.php |
| 286 | 仓库其他取 | template/xy286.php |
| 290 | 仓库物品取出 | template/xy290.php |
| 291 | 仓库装备取出 | template/xy291.php |
| 292 | 仓库其他取出 | template/xy292.php |
| 293 | 仓库物品取出全部 | template/xy293.php |
| 294 | 仓库其他取出全部 | template/xy294.php |
| 295 | 游戏开局（选择门派） | template/xy295.php |
| 297 | 游戏开局（选择性别） | template/xy297.php |
| 298 | 游戏开局（输入名字） | template/xy298.php |
| 299 | 攻略/客服 | template/xy299.php |

##### 四、充值/副本/宠物/PK/排行榜 (cmd 301~400) → xy04.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 301 | 充值页面 | template/xy301.php |
| 302 | 活动领取 | template/xy302.php |
| 303 | 石头升级 | template/xy303.php |
| 304 | 石头升级（确认） | template/xy304.php |
| 305 | 重置快捷键 | template/xy305.php |
| 306 | VIP 特权介绍 | template/xy306.php |
| 307 | 福利领取页面 | template/xy307.php |
| 308 | 福利领取 | template/xy308.php |
| 310 | 制作宝石 | template/xy310.php |
| 312 | 英雄牌 ×10→万能钥匙 ×1 | template/xy312.php |
| 313 | 快速进行任务 | template/xy313.php |
| 315 | 重置副本 | template/xy315.php |
| 316 | 重置副本（确认） | template/xy316.php |
| 317 | 副本材料声望兑换 | template/xy317.php |
| 318 | 副本材料声望兑换（确认） | template/xy318.php |
| 319 | 求购官宅 | template/xy319.php |
| 320 | 求购官宅（确认） | template/xy320.php |
| 321 | 撤销求购官宅 | template/xy321.php |
| 322 | 出售官宅 | template/xy322.php |
| 328 | 法宝经验条 | template/xy328.php |
| 329 | 改名字 | template/xy329.php |
| 330 | 物品使用 +1 全部 | template/xy330.php |
| 331 | 物品使用 +5 全部 | template/xy331.php |
| 332 | 物品使用 +10 全部 | template/xy332.php |
| 333 | 物品使用全部 | template/xy333.php |
| 334 | 静止页面刷新 | template/xy334.php |
| 335 | 静止页面刷新 | template/xy335.php |
| 336 | 增值仓库 | template/xy336.php |
| 337 | 增值仓库物品信息 | template/xy337.php |
| 338 | 增值仓库取出 | template/xy338.php |
| 339 | 踢出国家 | template/xy339.php |
| 340 | 退出国家 | template/xy340.php |
| 341 | 解散国家 | template/xy341.php |
| 342 | 地图官宅 | template/xy342.php |
| 343 | 购买婚事 | template/xy343.php |
| 344 | 装备升级（确认） | template/xy344.php |
| 345 | 装备升星符升星 | template/xy345.php |
| 346 | 装备升星材料升星 | template/xy346.php |
| 347 | 装备打孔 | template/xy347.php |
| 348 | 打怪 | template/xy348.php |
| 349 | 自己死亡 | template/xy349.php |
| 350 | 对象死亡 | template/xy350.php |
| 351 | 副本如意传送门 | template/xy351.php |
| 352 | 气血榜 | template/xy352.php |
| 353 | 攻击榜 | template/xy353.php |
| 354 | 魔攻榜 | template/xy354.php |
| 355 | 防御榜 | template/xy355.php |
| 356 | 等级榜 | template/xy356.php |
| 357 | 银两榜 | template/xy357.php |
| 358 | 金豆榜 | template/xy358.php |
| 359 | 充值榜 | template/xy359.php |
| 360 | 宠物捕捉成功 | template/xy360.php |
| 361 | 宠物捕捉失败 | template/xy361.php |
| 362 | 宠物面板 | template/xy362.php |
| 363 | 宠物出战 | template/xy363.php |
| 364 | 宠物休息 | template/xy364.php |
| 365 | 宠物状态页面 | template/xy365.php |
| 366 | 宠物装备 | template/xy366.php |
| 367 | 查看宠物装备 | template/xy367.php |
| 368 | 查看宠物经验 | template/xy368.php |
| 369 | 宠物改名 | template/xy369.php |
| 370 | 宠物放生二次确认 | template/xy370.php |
| 371 | 宠物放生 | template/xy371.php |
| 372 | 查看可穿戴宠物装备 | template/xy372.php |
| 373 | 穿戴宠物装备 | template/xy373.php |
| 374 | 卸下宠物装备 | template/xy374.php |
| 375 | 宠物装备宝石镶嵌 | template/xy375.php |
| 376 | 宠物装备宝石镶嵌（确认） | template/xy376.php |
| 377 | 宠物装备宝石摘除 | template/xy377.php |
| 378 | 宠物装备打孔 | template/xy378.php |
| 379 | 宠物装备升级 | template/xy379.php |
| 380 | 宠物装备升星符升星 | template/xy380.php |
| 381 | 宠物装备材料升星 | template/xy381.php |
| 382 | 宠物装备打孔（二） | template/xy382.php |
| 383 | 宠物装备升级（二） | template/xy383.php |
| 384 | 宠物装备升星符升星（二） | template/xy384.php |
| 385 | 宠物装备材料升星（二） | template/xy385.php |
| 386 | 世界 Boss 战斗（二） | template/xy386.php |
| 389 | 国战攻击玩家 | template/xy389.php |
| 390 | 国战攻击玩家（二） | template/xy390.php |
| 391 | 国战攻击玩家（三） | template/xy391.php |
| 392 | 国战攻击玩家（四） | template/xy392.php |
| 393 | 脱离 PK | template/xy393.php |
| 394 | 被攻击 | template/xy394.php |
| 395 | 被打死 | template/xy395.php |
| 396 | 复活 | template/xy396.php |
| 397 | 复活（二） | template/xy397.php |
| 398 | 安全区域禁止 PK | template/xy398.php |
| 399 | 对手已离开 | template/xy399.php |
| 400 | 物品详情 | template/xy400.php |

##### 五、挑战/修炼/活动/拍卖/称号 (cmd 401~500) → xy05.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 401 | 挑战 | template/xy401.php |
| 402 | 擂台 | template/xy402.php |
| 403 | 娱乐 | template/xy403.php |
| 404 | 攻略 | template/xy404.php |
| 405 | 升级攻略 | template/xy405.php |
| 406 | 装备攻略 | template/xy406.php |
| 407 | 副本攻略 | template/xy407.php |
| 408 | 活跃 | template/xy408.php |
| 409 | 签到 | template/xy409.php |
| 410 | 宣传 | template/xy410.php |
| 411 | 签到（执行） | template/xy411.php |
| 412 | 签到奖励一览 | template/xy412.php |
| 413 | 答题 | template/xy413.php |
| 414 | 万恶的班主任（开始答题） | template/xy414.php |
| 415 | 查看打造装备 | template/xy415.php |
| 416 | 通天塔奖励介绍 | template/xy416.php |
| 417 | 黄金贵族 | template/xy417.php |
| 418 | 铂金贵族 | template/xy418.php |
| 419 | 钻石皇族 | template/xy419.php |
| 420 | 至尊皇族 | template/xy420.php |
| 421 | 升星符祝融台 | template/xy421.php |
| 422 | 万能果商店 | template/xy422.php |
| 423 | 万能果商店（二） | template/xy423.php |
| 424 | 使用丹药情况一览 | template/xy424.php |
| 425 | 丹药描述 | template/xy425.php |
| 426 | 使用丹药情况一览（二） | template/xy426.php |
| 427 | 修炼界面 | template/xy427.php |
| 428 | 修炼血 | template/xy428.php |
| 429 | 修炼攻 | template/xy429.php |
| 430 | 修炼魔 | template/xy430.php |
| 431 | 修炼防 | template/xy431.php |
| 432 | 修炼介绍 | template/xy432.php |
| 433 | 修炼血（执行） | template/xy433.php |
| 434 | 修炼攻（执行） | template/xy434.php |
| 435 | 修炼魔（执行） | template/xy435.php |
| 436 | 修炼防（执行） | template/xy436.php |
| 437 | 摇点金豆池 | template/xy437.php |
| 438 | 筹众摇点玩法说明 | template/xy438.php |
| 439 | 随机摇点 | template/xy439.php |
| 440 | 摇点金豆池（二） | template/xy440.php |
| 441 | 摇点银两池 | template/xy441.php |
| 442 | 摇点银两池（二） | template/xy442.php |
| 443 | 摇点排行9 | template/xy443.php |
| 444 | 摇点排行10 | template/xy444.php |
| 445 | 摇点排行11 | template/xy445.php |
| 446 | 摇点排行12 | template/xy446.php |
| 447 | 活动充值榜 | template/xy447.php |
| 448 | 精魄兑换宠物蛋 | template/xy448.php |
| 449 | 百年打包 | template/xy449.php |
| 450 | 挑战面板 | template/xy450.php |
| 451 | 十八层地狱 | template/xy451.php |
| 452 | 十八层地狱说明 | template/xy452.php |
| 453 | 宠物初始属性 | template/xy453.php |
| 454 | 金银山寻宝 | template/xy454.php |
| 455 | 金银山寻宝介绍 | template/xy455.php |
| 456 | 探险福兑换 | template/xy456.php |
| 457 | 称号详情 | template/xy457.php |
| 458 | 清除搜索记录 | template/xy458.php |
| 459 | 拳头竞猜（玩家） | template/xy459.php |
| 460 | 拳头竞猜左手 | template/xy460.php |
| 461 | 拳头竞猜右手 | template/xy461.php |
| 462 | 左开拳 | template/xy462.php |
| 463 | 提现 | template/xy463.php |
| 464 | 提现（确认） | template/xy464.php |
| 465 | 右开拳 | template/xy465.php |
| 466 | 撤销 | template/xy466.php |
| 467 | 金豆泡泡（玩家） | template/xy467.php |
| 468 | 真吹泡 | template/xy468.php |
| 469 | 假吹泡 | template/xy469.php |
| 470 | 撤销 | template/xy470.php |
| 471 | 真泡 460 | template/xy471.php |
| 472 | 真泡 461 | template/xy472.php |
| 474 | 丢弃宝石 | template/xy474.php |
| 475 | 丢弃全部宝石 | template/xy475.php |
| 476 | 腾云驾雾 | template/xy476.php |
| 477 | 称号一览 | template/xy477.php |
| 478 | 称号一览（二） | template/xy478.php |
| 479 | 称号一览（三） | template/xy479.php |
| 480 | 紫霞活动 | template/xy480.php |
| 481 | 紫霞活动（二） | template/xy481.php |
| 482 | 宝石熔炼西游声望 | template/xy482.php |
| 483 | 宝石熔炼西游声望（确认） | template/xy483.php |
| 484 | 宠物升星 | template/xy484.php |
| 485 | 宠物升星（确认） | template/xy485.php |
| 486 | 练星符练星台 | template/xy486.php |
| 487 | 练星符详情 | template/xy487.php |
| 488 | 许愿奖励兑换 | template/xy488.php |
| 489 | 拍卖场书卷 | template/xy489.php |
| 490 | 拍卖场材料 | template/xy490.php |
| 491 | 拍卖场装备 | template/xy491.php |
| 492 | 拍卖场商城 | template/xy492.php |
| 493 | 拍卖场丹药 | template/xy493.php |
| 494 | 拍卖场任务 | template/xy494.php |
| 495 | 拍卖场农场 | template/xy495.php |
| 496 | 拍卖场宝箱 | template/xy496.php |
| 497 | 拍卖场宝石 | template/xy497.php |
| 498 | 拍卖页面 | template/xy498.php |
| 499 | 拍卖页面（二） | template/xy499.php |
| 500 | 拍卖页面（三） | template/xy500.php |

##### 六、红包/星盘/国家商城/赠送/拍卖购买 (cmd 501~600) → xy06.php

（含 fallback，若未显式映射会尝试加载 `template/xy{cmd}.php`）

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 501 | 拍卖页面（四） | template/xy501.php |
| 502 | 正在拍卖 | template/xy502.php |
| 503 | 正在拍卖（二） | template/xy503.php |
| 504 | 拍卖取回 | template/xy504.php |
| 505 | 拍卖场材料 | template/xy505.php |
| 506 | 拍卖场材料购买 | template/xy506.php |
| 507 | 拍卖场商城 | template/xy507.php |
| 508 | 拍卖场商城购买 | template/xy508.php |
| 509 | 拍卖场丹药 | template/xy509.php |
| 510 | 拍卖场丹药购买 | template/xy510.php |
| 511 | 拍卖场任务 | template/xy511.php |
| 512 | 拍卖场任务购买 | template/xy512.php |
| 513 | 拍卖场农场 | template/xy513.php |
| 514 | 拍卖场农场购买 | template/xy514.php |
| 515 | 拍卖场宝箱 | template/xy515.php |
| 516 | 拍卖场宝箱购买 | template/xy516.php |
| 517 | 宝石升级 | template/xy517.php |
| 518 | 宝石详细信息 | template/xy518.php |
| 519 | 宝石升级（确认） | template/xy519.php |
| 520 | 领取金豆 | template/xy520.php |
| 521 | 金豆领取说明 | template/xy521.php |
| 522 | PK | template/xy522.php |
| 523 | 战胜 | template/xy523.php |
| 524 | 孟婆 | template/xy524.php |
| 525 | 孟婆（二） | template/xy525.php |
| 526 | 孟婆（三） | template/xy526.php |
| 527 | *（无注释）* | template/xy527.php |
| 528 | *（无注释）* | template/xy528.php |
| 529 | 升星魂熔炼 | template/xy529.php |
| 530 | 圣灵图纸→噬魂图纸 | template/xy530.php |
| 531 | 圣灵图纸→噬魂图纸（确认） | template/xy531.php |
| 532 | 熔炼财宝箱和大财宝箱 | template/xy532.php |
| 533 | 充值 | template/xy533.php |
| 534 | PK 吃药 | template/xy534.php |
| 535 | 银两转换 | template/xy535.php |
| 536 | 银块详情 | template/xy536.php |
| 537 | 赠银 | template/xy537.php |
| 538 | 赠物（书卷） | template/xy538.php |
| 539 | 赠物（材料） | template/xy539.php |
| 540 | 赠物（装备） | template/xy540.php |
| 541 | 赠物（商城） | template/xy541.php |
| 542 | 赠物（丹药） | template/xy542.php |
| 543 | 赠物（任务） | template/xy543.php |
| 544 | 赠物（农场） | template/xy544.php |
| 545 | 赠物（宝箱） | template/xy545.php |
| 546 | 赠物（其他） | template/xy546.php |
| 547 | 赠物详细情况 | template/xy547.php |
| 548 | 赠送 | template/xy548.php |
| 549 | 清除搜索记录 | template/xy549.php |
| 550 | 广告 | template/xy550.php |
| 551 | 脑筋急转弯老师（活动） | template/xy551.php |
| 552 | 脑筋急转弯老师（答题） | template/xy552.php |
| 553 | 积分排行榜（活动） | template/xy553.php |
| 554 | 提交课本 | template/xy554.php |
| 555 | 充值排行榜（活动） | template/xy555.php |
| 556 | 欢喜财神 | template/xy556.php |
| 557 | 召唤 | template/xy557.php |
| 558 | 召唤（确认） | template/xy558.php |
| 559 | 天天领红包 | template/xy559.php |
| 560 | 天蓬元帅 | template/xy560.php |
| 561 | 天天领红包（二） | template/xy561.php |
| 562 | 陈号 | template/xy562.php |
| 563 | 陈号（二） | template/xy563.php |
| 564 | 财神驾到 | template/xy564.php |
| 565 | 财神（小） | template/xy565.php |
| 566 | 财神（小，二） | template/xy566.php |
| 567 | 财神倍数 | template/xy567.php |
| 568 | 兑换财神 | template/xy568.php |
| 569 | 兑换财神（确认） | template/xy569.php |
| 570 | 红包挖宝 | template/xy570.php |
| 571 | 红包倍数 | template/xy571.php |
| 572 | 真红包 | template/xy572.php |
| 573 | 假红包 | template/xy573.php |
| 574 | 支付宝购买红包 | template/xy574.php |
| 575 | 微信购买红包 | template/xy575.php |
| 576 | 支付宝二维码 | template/xy576.php |
| 577 | 微信二维码 | template/xy577.php |
| 578 | 支付宝启动 | template/xy578.php |
| 579 | 红包折现 | template/xy579.php |
| 580 | 绑定支付宝 | template/xy580.php |
| 581 | 绑定微信 | template/xy581.php |
| 582 | 领取红包 | template/xy582.php |
| 583 | 购买红包 | template/xy583.php |
| 584 | 购买红包（二） | template/xy584.php |
| 585 | 占星 | template/xy585.php |
| 586 | 占星说明 | template/xy586.php |
| 587 | 占星兑换 | template/xy587.php |
| 588 | 占星商品详细 | template/xy588.php |
| 589 | 星盘 | template/xy589.php |
| 590 | 激活星盘 | template/xy590.php |
| 591 | 注入星盘 | template/xy591.php |
| 592 | 注入星盘（二） | template/xy592.php |
| 593 | 注入星盘详情 | template/xy593.php |
| 594 | 卸下星盘 | template/xy594.php |
| 595 | 升级国家 | template/xy595.php |
| 596 | 二级国家商城 | template/xy596.php |
| 597 | 三级国家商城 | template/xy597.php |
| 598 | 四级国家商城 | template/xy598.php |
| 599 | 五级国家商城 | template/xy599.php |
| 600 | 六级国家商城 | template/xy600.php |

##### 七、节日活动/农场/武道会/VIP (cmd 601~685) → xy07.php

| cmd | 功能 | 模板文件 |
|-----|------|----------|
| 601 | 七级国家商城 | template/xy601.php |
| 602 | 八级国家商城 | template/xy602.php |
| 603 | 九级国家商城 | template/xy603.php |
| 604 | 十级国家商城 | template/xy604.php |
| 605 | 国家兑换 | template/xy605.php |
| 606 | 国家商品详细 | template/xy606.php |
| 607 | 天降密宝 | template/xy607.php |
| 608 | 密宝兑换 | template/xy608.php |
| 609 | 中秋抢榜 | template/xy609.php |
| 610 | 中秋抢榜（二） | template/xy610.php |
| 611 | 改性别 | template/xy611.php |
| 612 | 改性别（确认） | template/xy612.php |
| 613 | 天降密宝（二） | template/xy613.php |
| 614 | 丹药属性 | template/xy614.php |
| 615 | 时装 | template/xy615.php |
| 616 | 擂台查看 | template/xy616.php |
| 617 | 擂台比武 | template/xy617.php |
| 618 | 比武 | template/xy618.php |
| 619 | 比失败 | template/xy619.php |
| 620 | 比胜利 | template/xy620.php |
| 621 | 膜拜 | template/xy621.php |
| 622 | 更新属性 | template/xy622.php |
| 623 | 武道会说明 | template/xy623.php |
| 624 | 武道会领取金豆奖励 | template/xy624.php |
| 625 | 武道会领取膜拜奖励 | template/xy625.php |
| 626 | 娱乐爬楼 | template/xy626.php |
| 627 | 娱乐爬楼摇点 | template/xy627.php |
| 628 | 娱乐爬楼（二） | template/xy628.php |
| 629 | 领取楼层奖励 | template/xy629.php |
| 630 | 领取楼层奖励（二） | template/xy630.php |
| 631 | 熔炼占星 | template/xy631.php |
| 632 | 描述 | template/xy632.php |
| 633 | 爬楼奖励 | template/xy633.php |
| 634 | 升国旗 | template/xy634.php |
| 635 | 国庆敲金蛋 | template/xy635.php |
| 636 | 国庆敲金蛋（二） | template/xy636.php |
| 637 | 国庆抢榜 | template/xy637.php |
| 638 | 国庆挖宝 | template/xy638.php |
| 639 | 国庆图 | template/xy639.php |
| 640 | 国庆图挖宝 | template/xy640.php |
| 641 | 诛仙台 | template/xy641.php |
| 642 | 诛仙台（二） | template/xy642.php |
| 643 | 采花大盗 | template/xy643.php |
| 644 | 采花大盗排名 | template/xy644.php |
| 645 | 采花大盗排名奖励 | template/xy645.php |
| 646 | 采花说明 | template/xy646.php |
| 647 | 一键兑换修炼经验丹 | template/xy647.php |
| 648 | 尊贵 VIP 详细特权 | template/xy648.php |
| 649 | 尊贵 VIP 开 | template/xy649.php |
| 650 | 尊贵 VIP 关 | template/xy650.php |
| 651 | 西游蛋糕 | template/xy651.php |
| 652 | 伏羲阵图玩法介绍 | template/xy652.php |
| 653 | 实现愿望 | template/xy653.php |
| 654 | 实现愿望（二） | template/xy654.php |
| 655 | 活动丹药 | template/xy655.php |
| 656 | 半周年称号 | template/xy656.php |
| 657 | 使用护身符跳阵 | template/xy657.php |
| 658 | 农场 | template/xy658.php |
| 659 | 农场（二） | template/xy659.php |
| 660 | 农场施肥 | template/xy660.php |
| 661 | 植物升级 | template/xy661.php |
| 662 | 植物收获 | template/xy662.php |
| 663 | 植物收获（二） | template/xy663.php |
| 664 | 植物收获（三） | template/xy664.php |
| 665 | 加速卡 | template/xy665.php |
| 666 | 重阳活动称号面板 | template/xy666.php |
| 667 | 提交课本 | template/xy667.php |
| 668 | 指引 | template/xy668.php |
| 669 | 星币重置大楼 | template/xy669.php |
| 670 | 猜糖果颜色（积分） | template/xy670.php |
| 671 | 猜糖果颜色（奖励） | template/xy671.php |
| 672 | 紫星币重置猜糖果颜色（奖励） | template/xy672.php |
| 673 | 万圣节活动称号 | template/xy673.php |
| 674 | 紫星币重置猜糖果颜色（奖励二） | template/xy674.php |
| 675 | SDK 码兑换描述（一） | template/xy675.php |
| 676 | SDK 码兑换描述（二） | template/xy676.php |
| 677 | SDK 码兑换描述（三） | template/xy677.php |
| 678 | SDK 码兑换描述（四） | template/xy678.php |
| 679 | SDK 码兑换描述（五） | template/xy679.php |
| 680 | SDK 码兑换 | template/xy680.php |
| 681 | 详细 | template/xy681.php |
| 682 | 竞猜 | template/xy682.php |
| 683 | 竞猜（二） | template/xy683.php |
| 684 | 紫星购买竞猜 | template/xy684.php |
| 685 | 详情 | template/xy685.php |

##### 八、扩展页面 (cmd 686~691) → fallback 加载

这些命令没有在路由文件中显式映射，由 xy06.php 或 xy07.php 的 fallback 机制自动加载。

| cmd | 功能 | 模板文件 | 备注 |
|-----|------|----------|------|
| 686 | 新增任务系统入口 | template/xy686.php | 根据 NPC 参数转发到 rw/rw.php |
| 687 | 退出登录 | template/xy687.php | 清空 session 跳回首页 |
| 688 | 中秋积分兑换桂花糕 | template/xy688.php | 活动兑换 |
| 689 | 一键任务材料兑换声望 | template/xy689.php | 批量兑换 |
| 690 | 小地图缩放操作 | template/xy690.php | 地图尺寸 ±2 |
| 691 | 传送玩家到指定坐标 | template/xy691.php | NPC 参数 x_y 格式 |

##### 九、特殊模板（非 cmd 路由）

这些文件在 template/ 目录但通过直接 include 调用，不走 cmd 路由：

| 文件 | 功能说明 |
|------|----------|
| template/fhgame.php | 公共底部导航（返回游戏/首页等链接） |
| template/dd.php | 公共顶部/调试信息 |
| template/seach.php | 搜索功能 |
| template/seach1.php | 搜索功能（二） |
| template/xy10000.php | 小地图绘制时操作房间距离 |

##### 路由文件树

```
xy.php           ← 主引擎：认证、防刷、cmd 范围分发
├── xy01.php     ← cmd 1~100（核心：状态/背包/技能/装备/副本）
├── xy02.php     ← cmd 101~200（社交：宠物/住宅/国家/攻城）
├── xy03.php     ← cmd 201~300（系统：设置/挂售/仓库/开局）
├── xy04.php     ← cmd 301~400（战斗：PK/排行榜/宠物/充值）
├── xy05.php     ← cmd 401~500（修炼：挑战/修炼/活动/拍卖）
├── xy06.php     ← cmd 501~600（红包/财神/占星/赠送）+ fallback
└── xy07.php     ← cmd 601~20000（活动/VIP/农场/武道会）+ fallback
```

> 总计映射：~320 个显式 cmd → 模板 + ~6 个 fallback 扩展

#### 反作弊：超链接白名单

每个渲染出的页面上，所有可点击链接的 `cmd` 值都会被记录到 `user.ini` 的 `超链接值` section 中。下次请求时：
- 系统读取 `xcmid`（最小 cmd）和 `dcmid`（最大 cmd）
- 玩家提交的 `cmd` 必须在 `[xcmid, dcmid]` 范围内
- 超出范围 → 视为跳过页面 → 拒绝请求

这是一个朴素但有效的**状态机约束**，防止玩家通过修改 URL 参数跳转未解锁的页面。

#### 防过快刷新

`xy.php` 记录微秒时间戳到 `sjyz.ini`。连续两次请求间隔 < 100ms → 显示"刷新过快"提示页。

---

### 数据存储：DB + INI 双写模式

这是项目最核心的设计特征。

| 存储层 | 位置 | 内容 | 特点 |
|--------|------|------|------|
| MySQL | `xyy` 库 | 结构化持久数据（装备、宠物、技能等 74 张表） | 持久化，查询灵活 |
| INI 文件 | `fqxy/acher/{wjid}/` | 玩家运行时状态（地图坐标、当前页面、验证信息） | 每次读写都即时落盘 |

#### INI 文件结构

每个玩家在 `fqxy/acher/` 下有独立目录，包含多个 `.ini` 文件：
- `user.ini`：地图坐标 `[地图坐标]x/y`、当前页面 cmid、session sid、超链接范围等
- `zt.ini`：从 `all_zt` 表缓存的玩家属性
- `sjyz.ini`：时间验证（微秒时间戳，防刷新）
- 各地图区域 INI：如 `xsc0x1.ini`（新手村 0-1 坐标的状态）

#### `iniFile` 类 (`fqxy/class/iniclass.php`)

核心文件缓存引擎。使用 PHP 原生 `parse_ini_file()` 解析 INI 为二维数组（Section → 键值对），提供 `getItem/addItem/updItem/delItem` 等 CRUD 操作。所有写操作**立即 `save()` 同步落盘**，无内存缓存层。支持 `$fake = true` 只读模式。

> 设计权衡：INIO 文件的即时写入保证了数据安全（不怕进程崩溃），但代价是每次属性变更都触发磁盘 I/O。这是单机文字游戏的务实选择——玩家操作频率低，I/O 不是瓶颈。

---

### 游戏核心系统

| 系统 | 关键数据表 | 核心机制 |
|------|-----------|---------|
| **装备** | `zb`(身上)、`ckzb`(仓库)、`gszb`(挂售) | 5 孔镶嵌宝石、星级强化、佩戴位置 |
| **武器** | `wp`、`ckwp`、`gswp` | 分类和数量管理，支持仓库存取 |
| **宠物** | `cw`、`cwzbb`(宠物装备) | 刷星、变异、品质、出战/休息，可装备 |
| **技能** | `jnn` | 技能 ID + 等级，初始赠送 jnid=15,1 |
| **修炼** | `xl` | 类似技能，独立修炼体系 |
| **经济** | `all_yl`(银两)、`all_money`(金豆) | 背包银两 + 仓库银两分存，金豆为氪金货币 |
| **拍卖行** | `all_pm` | 全服共享拍卖，按分类出价 |
| **VIP** | `all_zt.vip/vipjy` | 0–20 级，经验累计，影响背包容量、IP 绑定数 |
| **排行** | `all_phb` | 气血/攻击/魔攻/防御/等级/银两/金豆/充值 八维排行 |
| **任务** | `yxrw` | 杀怪计数、状态流转、分类管理 |
| **帮派** | `all_bp` | 帮派经验、人数限制 |
| **副本** | `fb` | 时间记录、完成/次数管理 |
| **结婚** | `all_zt.peiou/peiouid` | 配偶名+ID，影响部分玩法 |
| **住宅** | `all_zt.zzmz/zzid/zzfl` | 住宅/豪宅/官宅三档 |
| **种植** | `zz` | 种植作物、成熟时间、收获时间 |
| **红包** | `all_hbmoney` | 总站红包记录，含金额和发送者 |

#### 数据设计细节
- **银两用 TEXT 类型**：支持超大数值（文字 MUD 数值膨胀的经典做法）
- **所有表均为 InnoDB**：支持事务和行级锁，多表写入原子性，崩溃自动恢复
- **初始角色**：新建角色赠送 88888 银两，背包 500、仓库 1000、挂售 2000，技能 jnid=15(某个基础技能) 和 jnid=1，等级 1

---

### 地图系统

#### 坐标模型
- `x`：地图区域编号（0=新手村、1=长安城、2=龙宫...）
- `y`：区域内子坐标编号

#### 数据来源
地图数据**硬编码在 PHP 文件中**（`fqxy/map/` 99 个文件）而非数据库。`mapid.php` 根据 `dtx` 加载对应地图文件，地图文件内用 `if (dty==0/1/2...)` 逐坐标硬编码 NPC 位置、场景描述、出口方向。

> 虽然 SQL 中定义了 `map` 表（含 up/down/left/right/up_jump 等出口字段），但实际游戏逻辑主要依赖 PHP 文件中的硬编码，map 表为辅助或历史遗留。

#### 地图交互
- `fznpc.php`：根据当前坐标查询 NPC 并生成交互链接
- `mapxx.php`：显示四方向出口和移动链接
- 方向移动 `clj` 值：3=上、4=下、5=左、6=右

---

### GM 管理后台

入口 `fqxy/gm.php`，通过 `gid` 参数分发到 63 个功能页面。

| 类别 | 功能 | gid |
|------|------|-----|
| 玩家查询 | 按 ID / 靓号查完整档案 | 4 |
| 物品发放 | 金豆、礼包、贵族卡、宝石、宠物蛋等 | 5–7 |
| 禁言管理 | 30分钟→永久封口，以及解禁 | 9–14 |
| 封号管理 | 1天→永久封禁，以及解封 | 15–20 |
| 系统消息 | 全服公告推送 | 8, 40–42 |
| 缓存刷新 | 单玩家 / 全服公共缓存 / 排行榜刷新 | 21–23, 37–38 |
| 充值处理 | 手动充值 10–2000 元 + 自动 VIP 升级 + 排行更新 | 29–36 |
| 订单管理 | 查看 / 清空充值订单 | 43–44 |
| 红包 | 发放充值红包（1/10/20/50/100 元）+ 记录管理 | 45–51 |
| 兑换码 | 提取宣传码、拉人码、福利码、新区码 | 57–61 |
| 统计 | 娱乐、天降财神、天降红包统计 | 52–56 |

GM 自身认证：通过 CURL 向家园 `/admin/validate.php` 验证 GM 账号密码，验证后 session 持久化。

---

## 目录骨架

```
xiyou/
├── index.php                    # 入口，302 → 家园登录
├── docker/                      # Docker 部署
│   ├── Dockerfile               #   镜像定义（php:7.4-apache + bcmath/mbstring）
│   ├── docker-compose.yml       #   服务编排（MySQL 5.7 + Apache）
│   └── entrypoint.sh            #   容器启动脚本（导表 + AUTO_INCREMENT 对齐 + 索引 + 权限）
├── docker_deploy.ps1            #   一键部署脚本（Windows PowerShell）
├── .dockerignore                #   Docker build 排除规则
├── config/                      # 家园配置
│   ├── config_example.php
│   └── Common.php               # config_item() 辅助函数
├── includes/                    # 公共库
│   ├── constants.php            # ROOT / JY_DIR / XY_DIR 常量
│   ├── db.php                   # DB 单例（封装 Medoo ORM）
│   ├── Medoo.php                # Medoo 轻量 MySQL ORM
│   ├── functions.php            # str_rand() 等通用函数
│   └── wrappers.php            # mysql_query→PDO 兼容层
├── xxjy/                        # 家园模块
│   ├── index.php                # 登录页（表单 + POST 验证）
│   ├── register.php             # 注册
│   ├── xywap.php                # 选区列表
│   ├── xxjyxg.php               # 修改密码
│   └── xxjywj.php               # 忘记密码
├── fqxy/                        # 游戏分区（主力目录，1700+ PHP 文件）
│   ├── xyy.php                  # 游戏入口（认证 + 角色创建 + 缓存初始化）
│   ├── xy.php                   # 游戏主循环（cmd 路由 + 反作弊 + 防刷新）
│   ├── xy01.php ~ xy07.php      # 分段路由（7 个文件覆盖全部 cmd）
│   ├── class/
│   │   ├── iniclass.php         # INI 文件读写引擎
│   │   └── MapGenerator/MapViewer.php
│   ├── sql/mysql.php            # 分区数据库连接
│   ├── sql/xxjyCurl.php         # CURL 跨服认证（客户端）
│   ├── xxsql/xxsql.php          # 新角色数据初始化（INSERT 大量表）
│   ├── template/                # 游戏页面模板（617 个）
│   ├── ini/                     # 公共 INI 缓存
│   ├── ache/{wjid}/             # 玩家 INI 缓存（运行时生成）
│   ├── acher/                   # 地图 INI 缓存（地图坐标、超链接白名单）
│   ├── map/                     # 地图逻辑（99 个文件，对应 99 个区域）
│   ├── npc/ + npcc/             # NPC 定义与交互
│   ├── rw/ + rcrw/ + rwxx/      # 任务系统
│   ├── fb/                      # 副本
│   ├── wp/ + pz/                # 武器 + 装备
│   ├── gw/                      # 怪物
│   ├── cw/                      # 宠物
│   ├── box/                     # 道具/宝箱
│   ├── msg/                     # 邮件
│   ├── admin/                   # 分区 GM 后台（66 个文件）
│   └── pic/                     # 图片资源（728 文件）
├── admin/                       # 总站 GM 入口
├── sql/                         # 总站数据库连接 + CURL 验证（服务端）
├── data/                        # SQL 文件
│   ├── xxjyuser.sql             # 家园库（1 表）
│   ├── xyy.sql                  # 分区库（74 表）
│   ├── auto_increment.sql       # AUTO_INCREMENT 计数器对齐
│   ├── add_indexes.sql          # 索引优化
│   └── migrate_to_innodb.sql    # MyISAM → InnoDB 迁移脚本
└── images/                      # 文档用图
```

---

## 技术特征总结

| 维度 | 实际情况 |
|------|---------|
| **框架** | 无框架，纯 PHP 原生 |
| **ORM** | Medoo（仅用于新代码，旧代码仍大量使用 `mysql_*` 兼容层） |
| **模板** | PHP 直出 HTML，无模板引擎，业务逻辑与视图混写 |
| **路由** | 手工 if/elseif 链，cmd 值分段 |
| **缓存** | 自研 INI 文件缓存，写操作即时同步落盘 |
| **数据库** | InnoDB 引擎，行级锁+事务，银两用 TEXT 防止溢出 |
| **跨服** | CURL + token + hash_equals + 来源 URL 校验 |
| **安全** | cmd 白名单范围校验、100ms 防过快刷新、session 持久化 |
| **兼容** | `wrappers.php` 将 `mysql_query()` 映射到 PDO，保证旧代码平滑运行 |
| **扩展** | 支持无限分区横向扩展，每个分区独立部署 |

---

## 二次开发注意事项

1. **不要轻易重构 cmd 路由**：700+ 个 cmd 值分散在大量模板的超链接中，牵一发而动全身。
2. **INI 缓存是单点依赖**：`iniFile` 类被几乎所有游戏页面引用，修改其行为前需要充分评估影响。注意代码实际读写的是 `fqxy/acher/` 目录（不是 `ache/`）。
3. **`mysql_*` 兼容层的局限**：`wrappers.php` 只覆盖了部分函数，新功能请直接使用 Medoo。
4. **InnoDB 事务**：涉及多表更新的操作可使用事务保证原子性，但旧代码为 auto-commit 模式，需显式开启。
5. **地图数据双源**：PHP 文件硬编码和 map 数据库表并存，修改地图时需确认同步。
6. **银两字段是 TEXT**：做数值计算时需要先 `(int)` 强转。

---

## 修改记录（相对原版《小轩西游》）

- PHP 5.6 → 7.4 → 8.2 全链路升级（原版仅支持 5.6，现已兼容 8.2）
- 引入 Medoo ORM + PDO 预处理
- `wrappers.php` 兼容层使旧 `mysql_*` 代码平滑迁移，`FETCH_BOTH→FETCH_ASSOC` 消除数字索引依赖
- 合并 `o_user_list` 表（原版数据表过多）
- 修复多项影响正常游玩的 Bug
- 删除原家园冗余页面
- **新增 Docker 部署支持**（一键部署，含 MySQL 5.7 + php:8.2-apache）
- **安装 bcmath / mbstring 扩展**（原版依赖的函数需这两个扩展）
- **修复 INI 缓存目录权限问题**（`acher/` 目录需 www-data 可写）
- **消除 MAX(id)+1 并发竞态**：uid 等主键改为 AUTO_INCREMENT，容器启动自动对齐计数器（#4.5）
- **MyISAM → InnoDB 全量迁移**：行级锁替代表级锁，支持事务，崩溃自动恢复（#5）
- **OPcache 缓存加速**：内存 256M + JIT tracing 50M buffer，1700+ PHP 文件免重复编译（#1 + #7）
- **静态资源 30 天浏览器缓存**：jpg/css/js 免重复下载（#2）
- **数据库连接复用**：Medoo `ATTR_PERSISTENT`（#3）
- **47 张表关键索引添加**：排行榜/装备/拍卖高频查询降低 50~80%（#4）
- **适配 MySQL 客户端 TLS**：`--ssl-verify-server-cert=0`（防 SSL 握手失败）
- 更多详见 [Commits](https://github.com/zither/xiyou/commits/master)

---

## 技术交流

QQ 群：**39387037**

> 本群仅限代码错误修复、功能优化等技术讨论，不提供安装指导，不接受新功能定制。

![群二维码](images/qun.jpg)
