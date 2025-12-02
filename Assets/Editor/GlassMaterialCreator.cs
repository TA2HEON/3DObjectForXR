using UnityEngine;
using UnityEditor;

public class GlassMaterialCreator : EditorWindow
{
    [MenuItem("Tools/Create Glass Materials")]
    static void CreateGlassMaterials()
    {
        // Materials 폴더 경로
        string materialsPath = "Assets/Materials";
        
        // 폴더가 없으면 생성
        if (!AssetDatabase.IsValidFolder(materialsPath))
        {
            AssetDatabase.CreateFolder("Assets", "Materials");
        }

        // 1. Clear Glass Material
        Material glassClear = new Material(Shader.Find("Standard"));
        glassClear.name = "Glass_Clear";
        glassClear.SetFloat("_Mode", 3); // Transparent
        glassClear.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
        glassClear.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        glassClear.SetInt("_ZWrite", 0);
        glassClear.DisableKeyword("_ALPHATEST_ON");
        glassClear.EnableKeyword("_ALPHABLEND_ON");
        glassClear.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        glassClear.renderQueue = 3000;
        glassClear.SetColor("_Color", new Color(0.9f, 0.95f, 1f, 0.3f));
        glassClear.SetFloat("_Metallic", 0f);
        glassClear.SetFloat("_Glossiness", 0.95f);
        glassClear.SetFloat("_GlossyReflections", 1f);
        AssetDatabase.CreateAsset(glassClear, materialsPath + "/Glass_Clear.mat");

        // 2. Tinted Glass Material
        Material glassTinted = new Material(Shader.Find("Standard"));
        glassTinted.name = "Glass_Tinted";
        glassTinted.SetFloat("_Mode", 3); // Transparent
        glassTinted.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
        glassTinted.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        glassTinted.SetInt("_ZWrite", 0);
        glassTinted.DisableKeyword("_ALPHATEST_ON");
        glassTinted.EnableKeyword("_ALPHABLEND_ON");
        glassTinted.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        glassTinted.renderQueue = 3000;
        glassTinted.SetColor("_Color", new Color(0.7f, 0.85f, 0.9f, 0.5f));
        glassTinted.SetFloat("_Metallic", 0f);
        glassTinted.SetFloat("_Glossiness", 0.9f);
        glassTinted.SetFloat("_GlossyReflections", 1f);
        AssetDatabase.CreateAsset(glassTinted, materialsPath + "/Glass_Tinted.mat");

        // 3. Frosted Glass Material
        Material glassFrosted = new Material(Shader.Find("Standard"));
        glassFrosted.name = "Glass_Frosted";
        glassFrosted.SetFloat("_Mode", 3); // Transparent
        glassFrosted.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
        glassFrosted.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        glassFrosted.SetInt("_ZWrite", 0);
        glassFrosted.DisableKeyword("_ALPHATEST_ON");
        glassFrosted.EnableKeyword("_ALPHABLEND_ON");
        glassFrosted.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        glassFrosted.renderQueue = 3000;
        glassFrosted.SetColor("_Color", new Color(1f, 1f, 1f, 0.7f));
        glassFrosted.SetFloat("_Metallic", 0f);
        glassFrosted.SetFloat("_Glossiness", 0.6f);
        glassFrosted.SetFloat("_GlossyReflections", 1f);
        AssetDatabase.CreateAsset(glassFrosted, materialsPath + "/Glass_Frosted.mat");

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log("Glass materials created successfully!");
        
        // 생성된 Material들을 선택
        Selection.objects = new Object[] { glassClear, glassTinted, glassFrosted };
    }
}

