using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class BalloonInfo
{
    public Transform Object;
    public AnimationCurve HeightCurve;

    public float MaxY = 1.5f;
    public Vector3 InitialPos;
    public Vector3 Speed;

    public float StartDelay = 5.0f;

    public float ResetPeriod = 10.0f;

    private float CurrentTime;

    public void Move(float dayPercent)
    {
        CurrentTime += Time.deltaTime;
        if(CurrentTime > StartDelay)
        {
            var pos = Object.position;
            pos += Time.deltaTime * Speed;

            if(pos.y > MaxY)
            {
                pos = InitialPos;
                CurrentTime = 0;
            }

            Object.position = pos;
        }
    }
}

public class CloudSceneController : MonoBehaviour
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
    public List<BalloonInfo> BalloonInfos;

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

        foreach(var balloonInfo in BalloonInfos)
        {
            balloonInfo.Move(dayPercent);

            //var pos = balloonInfo.Object.position;
            //var yValue = balloonInfo.HeightCurve.Evaluate(dayPercent);
            //pos.y = Mathf.Lerp(balloonInfo.MinY, balloonInfo.MaxY, yValue);
            //balloonInfo.Object.position = pos;
        }
    }
}
