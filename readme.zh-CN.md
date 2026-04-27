# eventkit-js

[English](./readme.md) | 简体中文

针对 Apple [EventKit](https://developer.apple.com/documentation/eventkit) 框架的 Node-API 封装 —— 在 macOS 上通过 Node.js 读写日历事件与提醒事项。

阶段 0–5（日历、事件读/写/流式、提醒事项）已完成。阶段 6 —— 闹钟、重复规则、参与者、结构化位置、日历 CRUD、变更通知 —— 已列入路线图；详见 [`CHANGELOG.md`](./CHANGELOG.md) 中的"Known limitations"。

## 安装

```bash
npm install eventkit-js
```

仅支持 macOS。`package.json` 中的 `os` 字段会阻止在 Linux 与 Windows 上安装。构建需要 Xcode Command Line Tools 与支持 C++17 的 clang（macOS 14+ 默认即可）。

## 权限与 `Info.plist`

在 macOS 14+ 上，`request*Access*` 方法仅当宿主应用的 bundle 包含对应的用途说明键时，才会弹出系统授权对话框：

- `NSCalendarsFullAccessUsageDescription`
- `NSRemindersFullAccessUsageDescription`

`node` 二进制本身并不携带这些键。直接用 `node` 调用 `requestFullAccessToEvents()` 会静默地 resolve 为 `false`。要走完整路径，请从带有这些键的已签名 app bundle 中运行。

## 快速上手 —— 事件

```ts
import { EKEventStore, EKEntityType, EKSpan } from "eventkit-js";

const store = EKEventStore.init();
await store.requestFullAccessToEvents();

// 在用户的默认日历中创建一个事件。
const cal = store.defaultCalendarForNewEvents;
store.save({
    title: "Project review",
    startDate: new Date("2026-05-01T15:00:00"),
    endDate:   new Date("2026-05-01T16:00:00"),
    calendar: cal,
}, EKSpan.THIS_EVENT);

// 读取某个时间窗内的事件。
const start = new Date(Date.now() - 7 * 86400 * 1000);
const end   = new Date(Date.now() + 7 * 86400 * 1000);
const cals  = store.calendars(EKEntityType.EVENT);
const events = store.eventsMatchingPredicate(
    store.predicateForEvents(start, end, cals)
);
for (const e of events) console.log(e.title, e.startDate);
```

## 快速上手 —— 提醒事项

```ts
import { EKEventStore } from "eventkit-js";

const store = EKEventStore.init();
await store.requestFullAccessToReminders();

const all = await store.fetchReminders(store.predicateForReminders(null));
for (const r of all) console.log(r.title, r.completed);
```

## 通过 `AbortSignal` 取消请求

```ts
const ctrl = new AbortController();
setTimeout(() => ctrl.abort(), 1000);
try {
    const reminders = await store.fetchReminders(p, { signal: ctrl.signal });
} catch (e: any) {
    if (e.name === "AbortError") {
        // 已超时
    }
}
```

该 signal 会中止外层 Promise。底层的原生 fetch 仍会继续执行，其结果会被丢弃。真正的原生侧取消尚未实现 —— 详见 [`CHANGELOG.md`](./CHANGELOG.md) 中的"Known limitations"。

## 流式读取事件

当结果集较大、不希望全部缓冲时，请使用 `enumerateEvents` 而非 `eventsMatchingPredicate`。在回调中抛出异常即可中止枚举：

```ts
const STOP = Symbol();
try {
    await store.enumerateEvents(p, (event) => {
        if (event.title?.includes("found it")) throw STOP;
        process(event);
    });
} catch (e) {
    if (e !== STOP) throw e;
}
```

## API 参考

各方法的状态、签名与数据结构：[`docs/coverage.md`](./docs/coverage.md)。

## 版本管理

遵循标准 [semver](https://semver.org/)。阶段 6 的新功能以 minor 版本发布。保持行为不变的修复为 patch。破坏性变更（签名、返回结构、移除的导出项）为 major。1.0 之前的开发不计入版本历史。

详见 [`CHANGELOG.md`](./CHANGELOG.md)。

## 许可

ISC，详见 [`LICENSE`](./LICENSE)。
