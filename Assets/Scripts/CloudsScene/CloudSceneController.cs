using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CloudSceneController : MonoBehaviour
{
    [Header("Settings")]
    public Gradient SkyTopColor;
    public Gradient SkyBottomColor;
    public Gradient CloudsColor;
    public AnimationCurve StarsIntensity;
    public AnimationCurve EmissionIntensity;
    public float DayDuration = 5.0f;
    public float PauseDayAtTime = 10.0f;

    [Header("Balloon Settings")]
    public int BalloonNum = 5;
    public Balloon BalloonPrefab;
    public float BalloonSpawnRate = 5.0f;
    public Transform Player;
    public float StopSpawnBalloonsTime = 15.0f;

    [Header("Stars Settings")]
    public FallingStars FallingStars;
    public float StartSpawnStarsTime = 25.0f;

    [Header("References")]
    public CloudRaymarchingCamera CloudRaymarching;
    public Transform DirLight;

    private float CurrentDayTime = 0;

    private List<Balloon> BalloonPool = new List<Balloon>();
    private float BalloonSpawnTime = 0.0f;

    private void Start()
    {
        for (int i = 0; i < BalloonNum; i++)
        {
            var balloon = Instantiate(BalloonPrefab, transform);
            balloon.gameObject.SetActive(false);
            BalloonPool.Add(balloon);
        }
    }

    private void UpdateSkyColor(float dayPercent)
    {
        var skyTop = SkyTopColor.Evaluate(dayPercent);
        var skyBottom = SkyBottomColor.Evaluate(dayPercent);
        var starsIntensity = StarsIntensity.Evaluate(dayPercent);

        RenderSettings.skybox.SetColor("_TopColor", skyTop);
        RenderSettings.skybox.SetColor("_BottomColor", skyBottom);
        RenderSettings.skybox.SetFloat("_StarsIntensity", starsIntensity);

        CloudRaymarching.CloudsColor = CloudsColor.Evaluate(dayPercent);
    }

    private void UpdateBalloons()
    {
        if(Time.time < StopSpawnBalloonsTime)
        {
            BalloonSpawnTime -= Time.deltaTime;
            if (BalloonSpawnTime <= 0.0f)
            {
                BalloonSpawnTime = BalloonSpawnRate;
                foreach (var balloon in BalloonPool)
                {
                    if (!balloon.IsActive)
                    {
                        balloon.StartFlight(Player);
                        break;
                    }
                }
            }
        }
    }

    private void UpdateStars()
    {
        if(!FallingStars.IsStarted && Time.time > StartSpawnStarsTime)
        {
            FallingStars.StartFalling();
        }
    }

    void Update()
    {
        if (CurrentDayTime > PauseDayAtTime)
        {
            return;
        }

        CurrentDayTime += Time.deltaTime;
        float dayPercent = Mathf.Clamp01(CurrentDayTime / DayDuration);

        UpdateSkyColor(dayPercent);
        UpdateBalloons();
        UpdateStars();

        Vector3 eulers = new Vector3(0.0f, 180 / DayDuration * Time.deltaTime, 0.0f);
        DirLight.Rotate(eulers, Space.World);
    }
}
