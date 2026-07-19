# Codex No Micro Launcher

Windows용 Codex 앱에서 선택적 Codex Micro/Work Louder 장치를 찾기 위해 실행되는
HID 탐색을 복제 런타임에서 비활성화하는 비공식 호환성 런처입니다.

일부 시스템에서 약 10초 간격으로 Codex UI와 Windows 입력이 순간적으로 멈추는
현상을 우회하기 위해 제작했습니다. 모든 입력 지연의 원인이 동일한 것은 아니므로,
이 런처가 모든 환경의 끊김을 해결한다고 보장하지는 않습니다.

## 지원 범위

- 운영체제: Windows 10/11 x64
- Codex: Microsoft Store에서 설치한 `OpenAI.Codex`
- 확인된 Codex 버전: `26.715.4045.0`
- 관리자 권한: 필요 없음
- 원본 Store 패키지와 사용자 설정: 수정하지 않음

OpenAI가 Codex 내부 구조를 변경하면 기존 패치 문자열을 찾지 못할 수 있습니다.
런처는 패치 위치가 정확히 한 곳인지 확인하고, 조건이 맞지 않으면 원본을 수정하지
않은 채 중단합니다.

## 다운로드 및 설치

1. [최신 릴리스](https://github.com/servaltullius/codex-no-micro-launcher/releases/latest)에서
   `Codex-No-Micro-v0.1.0.zip`을 내려받습니다.
2. ZIP 압축을 완전히 풉니다.
3. 일반 Codex를 트레이 아이콘까지 완전히 종료합니다.
4. `Install.cmd`를 실행합니다.
5. 설치가 끝나면 바탕화면의 **Codex (No Micro)** 바로가기를 사용합니다.

Windows에서 인터넷에서 받은 파일이라는 경고가 표시될 수 있습니다. 실행하기 전에
`Codex-No-Micro.ps1` 내용을 직접 확인하고, 릴리스의 `SHA256SUMS.txt`와 파일 해시를
비교할 수 있습니다.

## 작동 방식

1. 설치된 최신 `OpenAI.Codex` Store 패키지를 확인합니다.
2. 앱을 `%LOCALAPPDATA%\OpenAI\CodexNoMicro\runtimes\<Codex 버전>`으로 복사합니다.
3. 복사본의 `app.asar`에서 확인된 장치 탐색 호출 한 곳만 같은 길이의 빈 배열로
   교체합니다.
4. 원본과 패치본의 길이와 SHA-256, 패치 위치를 `patch-manifest.json`에 기록합니다.
5. 복제본의 `ChatGPT.exe`를 실행합니다.

런처는 네트워크 다운로드를 수행하지 않으며, 현재 PC에 설치된 Codex 파일만
사용합니다. 첫 준비에는 원본 앱과 비슷한 추가 디스크 공간과 복사 시간이 필요합니다.

## Codex 업데이트

바탕화면 바로가기를 실행할 때 Store 패키지 버전을 확인합니다. 새 버전이면 새로운
버전 디렉터리를 만들고 다시 검증·패치합니다. 같은 버전이면 준비된 런타임을 즉시
재사용합니다.

버전 감지는 자동이지만 내부 코드 변경까지 자동으로 추측하지는 않습니다. 패치
패턴이 달라졌다면 안전하게 중단하며, 그 버전을 지원하는 새 런처 릴리스가 필요합니다.

## 바뀌는 기능

- Codex Micro/Work Louder 하드웨어 탐색 호출만 비활성화합니다.
- 일반 작업, 모델, 플러그인, MCP, Computer Use 동작은 유지하는 것을 목표로 합니다.
- Microsoft Store 원본 앱과 `%USERPROFILE%\.codex`는 수정하지 않습니다.

## 상태 확인

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:LOCALAPPDATA\OpenAI\CodexNoMicro\Codex-No-Micro.ps1" -Action Status
```

## 현재 Codex 버전 미리 준비

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:LOCALAPPDATA\OpenAI\CodexNoMicro\Codex-No-Micro.ps1" -Action Prepare
```

## 제거

일반 Codex와 Codex (No Micro)를 모두 종료하고 `Uninstall.cmd`를 실행합니다.
별도 복제 런타임과 바로가기만 삭제되며 Microsoft Store의 원본 Codex는 유지됩니다.

## 검증 결과

`26.715.4045.0`에서 Store 원본과 No Micro 복제본을 약 32초 동안 동시에 측정했습니다.

| 런타임 | 180ms 이상 지연 | 최대 지연 |
|---|---:|---:|
| Store 원본 | 3회 | 252.87ms |
| No Micro 복제본 | 0회 | 0.98ms |

자세한 조건과 파일 해시는 [VERIFICATION.md](VERIFICATION.md)에 기록했습니다.

## 문제 보고

이슈를 등록할 때 다음 결과를 함께 첨부해 주세요. 사용자 이름이나 개인 경로는
가린 뒤 올리는 것을 권장합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:LOCALAPPDATA\OpenAI\CodexNoMicro\Codex-No-Micro.ps1" -Action Status
```

로그는 `%LOCALAPPDATA%\OpenAI\CodexNoMicro\launcher.log`에 있습니다.

## 면책

이 프로젝트는 비공식 커뮤니티 도구이며 OpenAI, Microsoft, Work Louder와 관련이
없습니다. 앱 업데이트로 언제든 동작하지 않을 수 있습니다. 공식 앱에 해당 탐색을
비활성화하는 설정이나 수정이 제공되면 이 런처를 제거하고 공식 기능을 사용하세요.

## 라이선스

런처 소스는 [MIT License](LICENSE)로 배포합니다. Codex 앱 및 관련 상표의 권리는
각 소유자에게 있으며, 이 저장소와 릴리스에는 Codex 앱 바이너리를 포함하지 않습니다.
