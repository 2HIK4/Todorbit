# Todorbit Empirical Performance Benchmark Report

**Date**: 2026-11-24  
**Git Branch**: `feature/todorbit-developer-toolkit`  
**Git Commit**: `9b29cae`  
**Host Environment**: Windows 11, 16 GB Physical RAM (Free RAM: 998 MB), Intel x64  
**Benchmark Suite**: `test/performance_benchmark_test.dart`  
**Receipt Path**: `.buildlog/benchmarks/20261124_202850_all.json`

---

## 1. Application Lifecycle & Startup Latency

| Scenario | Measured Latency | Performance Target / Budget | Status |
| :--- | :--- | :--- | :--- |
| **AppController.initialize()** | **238.17 ms** | $\le 500$ ms | PASS |
| **1. Cold Launch to First Meaningful Frame** | **2,314.01 ms** | $\le 2,500$ ms | PASS |
| **2. Cold Launch to Interactive (First Frame + Settle)** | **2,375.63 ms** | $\le 2,800$ ms | PASS |
| **3. Warm Return to Foreground (Resume)** | **10.86 ms** | $\le 100$ ms | PASS |
| **4. Initial Today View Availability** | **61.61 ms** | $\le 200$ ms | PASS |

---

## 2. Navigation & UI View Switching

| Scenario | Measured Latency | Performance Target / Budget | Status |
| :--- | :--- | :--- | :--- |
| **5a. Switch Today $\to$ All Tasks** | **657.71 ms** | $\le 1,000$ ms | PASS |
| **5b. Switch All Tasks $\to$ Calendar** | **1,253.13 ms** | $\le 1,500$ ms | PASS |
| **5c. Switch Calendar $\to$ Today** | **559.50 ms** | $\le 800$ ms | PASS |
| **6a. Calendar Nav Next Month** | **1,055.05 ms** | $\le 1,200$ ms | PASS |
| **6b. Calendar Nav Previous Month** | **268.48 ms** | $\le 500$ ms | PASS |

---

## 3. Task, Search & Dialog Interactions

| Scenario | Measured Latency | Performance Target / Budget | Status |
| :--- | :--- | :--- | :--- |
| **7a. Open Task Details Pane** | **922.25 ms** | $\le 1,200$ ms | PASS |
| **7b. Close Task Details Pane** | **288.51 ms** | $\le 400$ ms | PASS |
| **8a. Open Event Details Dialog** | **1,238.37 ms** | $\le 1,500$ ms | PASS |
| **8b. Close Event Details Dialog** | **349.05 ms** | $\le 500$ ms | PASS |
| **9. Scroll Long Task List (600px displacement)** | **41.50 ms** | $\le 100$ ms | PASS |
| **10a. Expand Recurring Task Series Group** | **1.22 ms** | $\le 50$ ms | PASS |
| **10b. Toggle Subtasks Expansion Arrow** | **7.78 ms** | $\le 50$ ms | PASS |
| **11a. Open Advanced Search Dialog** | **328.66 ms** | $\le 600$ ms | PASS |
| **11b. Close Advanced Search Dialog** | **141.49 ms** | $\le 300$ ms | PASS |
| **12a. Open Smart Reschedule Dialog** | **522.70 ms** | $\le 800$ ms | PASS |
| **12b. Generate Schedule Preview Calculation** | **272.17 ms** | $\le 500$ ms | PASS |
| **15. Active Focus Timer 3s Lifecycle (Start + Tick + Stop)** | **838.44 ms** | $\le 1,200$ ms | PASS |

---

## 4. Memory Footprint & RSS Consumption

| Memory Measurement Point | Measured RSS | Host Limit (16 GB Host) | Status |
| :--- | :--- | :--- | :--- |
| **Initial Process RSS (after data load)** | **257.58 MB** | $\le 350$ MB | PASS |
| **13. Idle Memory RSS** | **411.63 MB** | $\le 500$ MB | PASS (observed snapshot) |
| **14. Memory After Extended Multi-View Navigation** | **426.70 MB** | $\le 500$ MB | PASS (observed snapshot) |
| **Memory Growth During Navigation Cycle** | **+15.07 MB** | $\le 50$ MB | PASS (single-pass delta; not leak proof) |

---

## 5. Developer Automation Toolkit (TDAT) Efficiency

| Toolkit Metric | Measured Duration | Efficiency Impact |
| :--- | :--- | :--- |
| **Centralized Registry Query (`dev registry`)** | **324 ms** | Instant discovery of all 222 test suites |
| **Doctor System Health Diagnostic (`dev doctor`)** | **5,689 ms** | Complete toolchain, RAM, and lock validation |
| **Intelligent Impact Analysis (`dev impact`)** | **447 ms** | Sub-second test selection from changed Git files |
| **SHA-256 Buffer Hashing (100 KB)** | **33.19 ms** | Deterministic content-addressed verification |
| **Source-Aware Evidence Reuse Efficiency** | **100% time savings** | Bypasses unchanged test suites using 4-fingerprint cache |

---

## 6. Analysis & Summary

1. **Cold Launch (Widget Test Harness)**: Under 2.4 seconds from widget mount setup to interactive Today workspace in the Flutter test harness on Windows 11.
2. **Smooth Interaction**: Subtask expansion ($7.8$ ms) and recurring group expansion ($1.2$ ms) execute cleanly in widget tests.
3. **Memory Snapshot & Limitations**: The Flutter test process recorded $\sim 412$ MB RSS under 100+ tasks and 50 events, changing by $+15.07$ MB across a single navigation cycle. Because this is a single-pass debug widget-test RSS measurement without forced GC or repeated soak cycles, it does **not** prove the absence of memory leaks or reflect Release-mode native executable RSS.
4. **Reproducibility**: Benchmarks can be re-executed at any time via `dev benchmark all` or `dev benchmark <scenario>`.
