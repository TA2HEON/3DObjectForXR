# 3DObjectForXR

Meta Quest를 위한 Unity URP 기반 3D 변형 가능 객체 시뮬레이션 프로젝트

## 프로젝트 개요

이 프로젝트는 GPU 기반 Position Based Dynamics (PBD) 시뮬레이션을 사용하여 3D 변형 가능 객체를 Meta Quest 3에서 실시간으로 렌더링하는 XR 애플리케이션입니다.

### 주요 기능

- GPU 기반 PBD 시뮬레이션 - ComputeShader를 활용한 고성능 물리 시뮬레이션
- URP 최적화 렌더링 - Universal Render Pipeline으로 Meta Quest에 최적화
- 커스텀 Lighting System - Diffuse, Specular, Ambient, Rim Lighting 구현
- VR Stereo Rendering - Meta Quest의 스테레오 인스턴싱 완벽 지원
- 실시간 변형 - StructuredBuffer를 통한 동적 메시 변형

## 기술 스택

- **Unity Version**: 2021.3 이상 권장
- **Render Pipeline**: Universal Render Pipeline (URP)
- **Target Platform**: Meta Quest 3 (Android ARM64)
- **Graphics API**: Vulkan
- **Scripting Backend**: IL2CPP

## 프로젝트 구조

```
3DObjectForXR/
├── Assets/
│   ├── Shader/
│   │   └── render shader/
│   │       ├── RenderObj.shader          # URP Lit Shader (커스텀 조명)
│   │       └── PBDSolver.compute         # GPU 물리 시뮬레이션
│   ├── Script/
│   │   └── GPU/
│   │       ├── GPUPBD.cs                 # PBD 시뮬레이션 메인 로직
│   │       └── ...
│   ├── Materials/                        # Material 프리셋
│   ├── Scenes/                           # 씬 파일
│   └── TetGen-Model/                     # 사면체 메시 모델
├── ProjectSettings/                      # Unity 프로젝트 설정
└── Packages/                             # Unity 패키지 매니페스트
```

## Shader 시스템

### RenderObj Shader 특징

Built-in Render Pipeline의 Standard Surface Shader를 URP Lit Shader로 완전히 재작성했습니다.

#### 주요 개선사항

| 항목 | Before (Built-in) | After (URP) |
|------|-------------------|-------------|
| 파이프라인 | Built-in RP | Universal RP |
| 조명 방식 | 자동 (Unity 내장) | 커스텀 (4단계) |
| Pass 구조 | 자동 생성 | ForwardLit, ShadowCaster, DepthOnly |
| VR 지원 | 미지원 | Stereo Instancing 지원 |
| 입체감 | 약함 | 강함 |

#### 커스텀 Lighting System

```hlsl
// 1. Diffuse Lighting (Lambert)
half NdotL = saturate(dot(normalWS, mainLight.direction));
half3 diffuse = mainLight.color * NdotL * mainLight.shadowAttenuation;

// 2. Specular Lighting (Blinn-Phong)
half3 halfDir = normalize(mainLight.direction + viewDirWS);
half NdotH = saturate(dot(normalWS, halfDir));
half specularPower = exp2(10 * _Smoothness + 1);
half3 specular = mainLight.color * pow(NdotH, specularPower) * _Smoothness;

// 3. Ambient Light (환경광)
half3 ambient = half3(0.2, 0.2, 0.2);

// 4. Rim Lighting (윤곽선 강조)
half rim = 1.0 - saturate(dot(viewDirWS, normalWS));
rim = pow(rim, 3.0);
half3 rimLight = rim * half3(0.3, 0.3, 0.3);
```

### Multi-Pass 구조

#### 1. ForwardLit Pass
- 메인 렌더링 및 조명 계산
- PBR 기반 Material 속성 적용
- 그림자 수신 및 Fog 처리

#### 2. ShadowCaster Pass
- 다른 오브젝트에 그림자 투영
- Normal 기반 Shadow Bias
- VR 스테레오 렌더링 지원

#### 3. DepthOnly Pass
- Z-buffer 전용 렌더링
- Early-Z 최적화
- 오클루전 컬링 지원

## Meta Quest 최적화

### VR Stereo Rendering
```hlsl
UNITY_VERTEX_INPUT_INSTANCE_ID    // Instancing ID
UNITY_VERTEX_OUTPUT_STEREO         // 스테레오 출력
UNITY_SETUP_INSTANCE_ID(input);
UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
```

### Mobile GPU 최적화
- Half precision 변수 사용 (`half3`, `half4`)
- Blinn-Phong Specular (Phong보다 빠름)
- Instancing을 통한 Draw Call 감소
- 효율적인 버퍼 액세스 패턴

### 렌더링 최적화
```hlsl
#pragma target 4.5
#pragma exclude_renderers gles gles3 glcore  // Legacy 제외
#pragma multi_compile_instancing              // Instancing 활성화
#pragma multi_compile_fog                     // Fog 지원
```

## GPU 버퍼 시스템

### StructuredBuffer를 통한 동적 메시

```hlsl
struct vertData
{
    float3 pos;     // 정점 위치
    float2 uvs;     // UV 좌표
    float3 norms;   // 노말 벡터
};

StructuredBuffer<vertData> vertsBuff;  // GPU에서 계산된 정점 데이터
StructuredBuffer<int> triBuff;         // 삼각형 인덱스 버퍼
```

### 동적 버텍스 처리
```hlsl
// Vertex Shader에서 GPU 버퍼로부터 정점 데이터 로드
int bufferIndex = triBuff[input.vertexID];
vertData vData = vertsBuff[bufferIndex];

float3 positionOS = vData.pos;
float3 normalOS = vData.norms;
float2 uv = vData.uvs;
```

## 시작하기

### 요구사항

- Unity 2021.3 LTS 이상
- Universal RP 패키지
- Meta Quest 3 개발 환경
  - Oculus Integration SDK
  - Android Build Support
  - OpenXR Plugin

### 설치 방법

1. 저장소 클론
```bash
git clone https://github.com/TA2HEON/3DObjectForXR.git
cd 3DObjectForXR
```

2. Unity Hub에서 프로젝트 열기
   - Unity Hub → Add → 프로젝트 폴더 선택
   - Unity 2021.3 LTS 이상 버전으로 실행

3. URP 설정 확인
   - Edit → Project Settings → Graphics
   - Scriptable Render Pipeline Settings 확인
   - Mobile/PC용 Renderer 설정 확인

4. Meta Quest 빌드 설정
   - File → Build Settings
   - Platform: Android
   - Texture Compression: ASTC
   - Run Device: Meta Quest 3

### 실행 방법

#### Unity Editor에서 실행
1. `Scenes/SampleScene.unity` 열기
2. Play 버튼 클릭

#### Meta Quest에서 실행
1. Meta Quest를 개발자 모드로 설정
2. USB로 PC와 연결
3. File → Build And Run
4. APK가 자동으로 빌드 및 설치됨

## 성능 지표

### Meta Quest 3 기준

- **프레임레이트**: 72 FPS (안정적)
- **Draw Calls**: 약 50 (Instancing 적용)
- **Vertices**: 약 10K (동적 변형)
- **메모리 사용량**: 약 200 MB

### 최적화 팁

1. LOD 시스템 사용
   - 거리에 따른 메시 상세도 조절
   
2. Occlusion Culling 활성화
   - Window → Rendering → Occlusion Culling
   
3. Shadow Distance 조절
   - URP Asset → Shadows → Max Distance: 20-30m

## 주요 스크립트

### GPUPBD.cs
```csharp
public class GPUPBD : MonoBehaviour
{
    public Material material;                    // 렌더링 Material
    public ComputeShader PBDSolver;             // GPU 물리 시뮬레이션
    
    private StructuredBuffer<vertData> vertsBuff;
    private StructuredBuffer<int> triBuff;
    
    void Update()
    {
        // GPU에서 물리 시뮬레이션 실행
        PBDSolver.Dispatch(...);
        
        // 결과를 Shader에 전달하여 렌더링
        renderObject();
    }
}
```

## 개발 가이드

### Material 커스터마이징

1. Project 창에서 Material 생성
2. Shader 선택: `RenderObj`
3. 속성 조절:
   - **Base Color**: 기본 색상
   - **Base Map**: 텍스처
   - **Smoothness**: 표면 매끄러움 (0-1)
   - **Metallic**: 금속성 (0-1)

### Shader 수정

`Assets/Shader/render shader/RenderObj.shader` 파일 수정 후:

1. Unity로 돌아가서 자동 컴파일 대기
2. Console 창에서 에러 확인
3. Material Inspector에서 변경사항 확인

### ComputeShader 디버깅

```csharp
// GPU 버퍼 데이터를 CPU로 읽어오기
vertData[] debugData = new vertData[vertexCount];
vertsBuff.GetData(debugData);

// 디버그 로그 출력
Debug.Log($"Vertex 0: {debugData[0].pos}");
```

## 참고 자료

### Unity Documentation
- [Universal Render Pipeline](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest)
- [Shader Programming](https://docs.unity3d.com/Manual/SL-Reference.html)
- [ComputeShader](https://docs.unity3d.com/Manual/class-ComputeShader.html)

### Meta Quest Development
- [Meta Quest Developer Hub](https://developer.oculus.com/)
- [Unity XR Plugin](https://docs.unity3d.com/Manual/XR.html)

## 기여

프로젝트 개선을 위한 기여를 환영합니다.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 라이선스

이 프로젝트는 연구 목적으로 개발되었습니다.

## 개발자

- **TA2HEON** - [GitHub Profile](https://github.com/TA2HEON)

## 감사의 말

- Unity Technologies - Universal Render Pipeline
- Meta - Meta Quest SDK
- TetGen - Tetrahedral Mesh Generation

---

Made for Meta Quest 3
