
using UnityEditor.Rendering.PostProcessing;

[PostProcessEditor(typeof(SSAO))]
public sealed class SSAOEditor : PostProcessEffectEditor<SSAO>
{
    SerializedParameterOverride m_Blend;
    SerializedParameterOverride m_DepthOrNormal;

    public override void OnEnable()
    {
        m_Blend = FindParameterOverride(x => x.blend);
        m_DepthOrNormal = FindParameterOverride(x => x.depthOrNormal);
    }

    public override void OnInspectorGUI()
    {
        PropertyField(m_Blend);
        PropertyField(m_DepthOrNormal);
    }
}
