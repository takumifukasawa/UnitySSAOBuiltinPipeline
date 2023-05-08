using UnityEditor.Rendering.PostProcessing;

[PostProcessEditor(typeof(SSAOHemisphere))]
public sealed class SSAOHemisphereEditor : PostProcessEffectEditor<SSAOHemisphere>
{
    SerializedParameterOverride m_Blend;
    SerializedParameterOverride m_OcclusionSampleLength;
    SerializedParameterOverride m_OcclusionMinDistance;
    SerializedParameterOverride m_OcclusionMaxDistance;
    SerializedParameterOverride m_OcclusionBias;
    SerializedParameterOverride m_OcclusionStrength;
    SerializedParameterOverride m_OcclusionColor;

    public override void OnEnable()
    {
        m_Blend = FindParameterOverride(x => x.Blend);
        m_OcclusionSampleLength = FindParameterOverride(x => x.OcclusionSampleLength);
        m_OcclusionMinDistance = FindParameterOverride(x => x.OcclusionMinDistance);
        m_OcclusionMaxDistance = FindParameterOverride(x => x.OcclusionMaxDistance);
        m_OcclusionBias = FindParameterOverride(x => x.OcclusionBias);
        m_OcclusionStrength = FindParameterOverride(x => x.OcclusionStrength);
        m_OcclusionColor = FindParameterOverride(x => x.OcclusionColor);
    }

    public override void OnInspectorGUI()
    {
        PropertyField(m_Blend);
        PropertyField(m_OcclusionSampleLength);
        PropertyField(m_OcclusionMinDistance);
        PropertyField(m_OcclusionMaxDistance);
        PropertyField(m_OcclusionBias);
        PropertyField(m_OcclusionStrength);
        PropertyField(m_OcclusionColor);
    }
}
