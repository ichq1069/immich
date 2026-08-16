# 任务清单 - R2 直链提取

## 1. 数据库

- [x] 1.1 创建 `r2_links` 数据表迁移文件

## 2. 后端核心

- [x] 2.1 创建 `R2LinkEntity` 实体
- [x] 2.2 创建 `IR2LinkRepository` 接口和实现
- [x] 2.3 创建 `R2LinkService` 服务（生成预签名 URL、路径转换、CRUD）
- [x] 2.4 创建 `R2LinkController` 控制器（API 接口）
- [x] 2.5 创建 `R2LinkModule` 模块并注册到 AppModule
- [x] 2.6 安装 `@aws-sdk/client-s3` 和 `@aws-sdk/s3-request-presigner` 依赖

## 3. Web 前端

- [ ] 3.1 资产详情页添加"获取 R2 直链"操作
- [ ] 3.2 时间线/相册视图多选后添加"批量获取 R2 直链"操作
- [ ] 3.3 创建 R2 直链管理页面

## 4. 移动端

- [ ] 4.1 资产详情页添加"获取 R2 直链"操作
- [ ] 4.2 多选资产后添加"批量获取 R2 直链"操作
- [ ] 4.3 设置页面添加"R2 直链管理"入口

## 5. 测试

- [ ] 5.1 后端服务单元测试
- [ ] 5.2 API 集成测试