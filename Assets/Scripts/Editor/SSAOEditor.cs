using UnityEditor.Rendering.PostProcessing;

[PostProcessEditor(typeof(SSAO))]
public sealed class SSAOEditor : PostProcessEffectEditor<SSAO>
{
    SerializedParameterOverride m_Blend;
    SerializedParameterOverride m_DepthOrNormal;
    SerializedParameterOverride m_OcclusionSampleLength;
    SerializedParameterOverride m_OcclusionMinDistance;
    SerializedParameterOverride m_OcclusionMaxDistance;
    SerializedParameterOverride m_OcclusionStrength;

    public override void OnEnable()
    {
        m_Blend = FindParameterOverride(x => x.Blend);
        m_DepthOrNormal = FindParameterOverride(x => x.DepthOrNormal);
        m_OcclusionSampleLength = FindParameterOverride(x => x.OcclusionSampleLength);
        m_OcclusionMinDistance = FindParameterOverride(x => x.OcclusionMinDistance);
        m_OcclusionMaxDistance = FindParameterOverride(x => x.OcclusionMaxDistance);
        m_OcclusionStrength = FindParameterOverride(x => x.OcclusionStrength);
    }

    public override void OnInspectorGUI()
    {
        PropertyField(m_Blend);
        PropertyField(m_DepthOrNormal);
        PropertyField(m_OcclusionSampleLength);
        PropertyField(m_OcclusionMinDistance);
        PropertyField(m_OcclusionMaxDistance);
        PropertyField(m_OcclusionStrength);
    }
}
