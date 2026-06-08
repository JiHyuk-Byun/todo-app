# Planner — macOS 메뉴바 Todo 앱

맥북 상단 메뉴바에서 오늘 할 일을 체크하고, 스케줄러에서 날짜별 계획과 반복 일정을 관리하는 SwiftUI 앱입니다.

## 기능
- **메뉴바 드롭다운** — 상단바의 체크리스트 아이콘을 클릭하면 오늘의 할 일이 나오고, 원형 체크박스로 완료를 토글합니다. 하단 입력창으로 바로 추가도 가능합니다.
- **스케줄러 창** — 달력에서 날짜를 고르면 그 날의 할 일을 추가/수정/삭제할 수 있습니다.
- **반복 일정** — "매일 운동", "매주 월·수·금"처럼 반복 규칙을 만들면 해당 날짜에 자동으로 할 일이 생성됩니다 (🔁 아이콘 표시).
- **로컬 저장** — `~/Library/Application Support/Planner/data.json` 에 자동 저장됩니다.

## 빌드 & 실행
```bash
./build.sh        # Planner.app 생성
open ./Planner.app # 메뉴바에 아이콘 등장
```
종료는 메뉴바 드롭다운의 "종료" 버튼.

## ⚠️ 빌드 전 필요: 툴체인 복구
현재 이 맥의 Command Line Tools가 깨져 있습니다
(컴파일러 `swiftlang-6.2.1.4.8` ↔ SDK `swiftlang-6.2.1.4.7` 불일치).
이 상태에서는 `import Foundation` 한 줄짜리 프로그램도 컴파일되지 않습니다.

다음 중 하나로 복구하세요:

**A. Command Line Tools 재설치 (간단)**
```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

**B. 전체 Xcode 설치 (권장 — 배포용 .app/서명/아카이브에 유리)**
App Store에서 Xcode 설치 후:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

복구 후 `./build.sh` 를 다시 실행하면 됩니다.

## 구조
```
Sources/Planner/
  PlannerApp.swift          # @main, MenuBarExtra + 스케줄러 Window, accessory 모드
  Models/
    Models.swift            # TodoItem, RecurringRule, Frequency, PlannerData
    Store.swift             # 영속화 + 반복 일정 자동 생성(materialize)
  Views/
    MenuBarView.swift       # 메뉴바 드롭다운 (오늘 할 일 + 체크)
    SchedulerView.swift     # 달력 + 날짜별 편집 + 반복 일정 관리
```

> 참고: `Package.swift` 도 포함돼 있으나, 같은 툴체인 문제로 SwiftPM 매니페스트 컴파일이
> 실패합니다. 툴체인 복구 후에는 `swift run` 또는 `./build.sh` 둘 다 사용 가능합니다.
