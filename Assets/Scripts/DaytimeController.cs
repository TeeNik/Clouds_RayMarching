using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DaytimeController : MonoBehaviour
{
    [Header("Settings")]
    public Gradient SkyTopColor;
    public Gradient SkyBottomColor;
    public Gradient CloudsColor;
    public AnimationCurve StarsIntensity;
    public AnimationCurve EmissionIntensity;
    public float DayDuration = 5.0f;

    [Header("References")]
    public CloudRaymarchingCamera CloudRaymarching;

    private float CurrentDayTime = 0;


    void Update()
    {
        CurrentDayTime += Time.deltaTime;
        float dayPercent = Mathf.Clamp01(CurrentDayTime / DayDuration);

        var skyTop = SkyTopColor.Evaluate(dayPercent);
        var skyBottom = SkyBottomColor.Evaluate(dayPercent);
        var starsIntensity = StarsIntensity.Evaluate(dayPercent);

        RenderSettings.skybox.SetColor("_TopColor", skyTop);
        RenderSettings.skybox.SetColor("_BottomColor", skyBottom);
        RenderSettings.skybox.SetFloat("_StarsIntensity", starsIntensity);
    }
}
