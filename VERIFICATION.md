# 설치 및 검증 결과

- 검증일: 2026-07-19 (Asia/Seoul)
- Codex Store 패키지: `OpenAI.Codex_26.715.4045.0_x64__2p2nqsd0c76g0`
- 패치 대상 수: 패치 전 `1`, 패치 후 `0`
- 패치 오프셋: `2441341`
- 원본/패치 `app.asar` 길이: 모두 `201157633`바이트
- 원본 SHA-256: `4F81FE8CFADD0ECD1D55A46F4B101B1DB70ABBB372B63A0120218B1D868008A3`
- 패치 SHA-256: `60E7D8E9F192337A4C97AD4BA79E8E909F7F4CCF7270C9CC9867FDA54060EF43`

## 동시 비교 측정

동일한 약 32초 동안 Microsoft Store 원본과 임시 프로필의 No Micro 패치본을
각각 120회 Windows 메시지 루프 방식으로 측정했습니다.

| 런타임 | 실패 | 50ms 이상 | 180ms 이상 | 평균 | 최대 |
|---|---:|---:|---:|---:|---:|
| Store 원본 | 0 | 3 | 3 | 5.64ms | 252.87ms |
| No Micro 패치본 | 0 | 0 | 0 | 0.13ms | 0.98ms |

원본 지연은 `07:52:03`, `07:52:13`, `07:52:24`에 각각 `199.37ms`,
`252.87ms`, `191.40ms`로 나타났습니다. 패치본에서는 동일한 10초 주기의 지연이
관측되지 않았습니다.

## 설치 위치

- 런처: `%LOCALAPPDATA%\OpenAI\CodexNoMicro\Codex-No-Micro.ps1`
- 현재 패치 런타임: `%LOCALAPPDATA%\OpenAI\CodexNoMicro\runtimes\26.715.4045.0`
- 바로가기: 바탕화면의 `Codex (No Micro)`
- 원본 Store 패키지: 변경 없음

## 갱신 동작 확인

현재 버전이 이미 준비된 상태에서 `Prepare`를 다시 실행했을 때 약 `697ms`에
완료됐으며 런타임을 다시 복사하거나 패치하지 않았습니다. Store 버전이 바뀔 때만 새
버전 디렉터리를 생성합니다.
