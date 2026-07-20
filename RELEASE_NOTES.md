# Codex No Micro Launcher v0.1.1

Windows PowerShell 5.1의 기본 코드페이지가 CP949인 PC에서 설치 스크립트가 깨질 수
있던 인코딩 호환성 문제를 수정한 릴리스입니다.

## 수정 사항

- `Codex-No-Micro.ps1`을 UTF-8 BOM으로 배포
- CP949 환경에서 발생하던 한국어 문자열 손상과 PowerShell 파싱 오류 방지
- 런처 패치 로직과 지원 Codex 버전은 `v0.1.0`과 동일

## 설치

1. `Codex-No-Micro-v0.1.1.zip`을 내려받아 압축을 풉니다.
2. 일반 Codex를 트레이까지 완전히 종료합니다.
3. `Install.cmd`를 실행합니다.
4. 바탕화면의 **Codex (No Micro)**를 사용합니다.

## 호환성

- 확인된 Codex Store 버전: `26.715.4045.0`
- Windows 10/11 x64용
- 비공식 커뮤니티 도구이며 OpenAI와 관련이 없습니다.

새 Codex 버전에서 내부 패턴이 바뀌면 런처는 수정하지 않고 안전하게 중단합니다.
