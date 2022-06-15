using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FallingStars : MonoBehaviour
{
    public Star StarPrefab;
    public int Amount = 1;
    public float Period = 5.0f;

    public Transform MinStart;
    public Transform MaxStart;
    public Transform MinEnd;
    public Transform MaxEnd;

    public List<Transform> StartPoints;
    public List<Transform> EndPoints;

    public bool IsStarted { get; private set; }

    public List<Star> Stars;
    private float CurrentTime;

    public void StartFalling()
    {
        IsStarted = true;
    }

    void Start()
    {
        //for(int i = 0; i < Amount; ++i)
        //{
        //    var star = Instantiate(StarPrefab, transform);
        //    star.gameObject.SetActive(false);
        //    Stars.Add(star);
        //}
    }

    void Update()
    {
        if (IsStarted)
        {
            CurrentTime -= Time.deltaTime;
            if (CurrentTime < 0)
            {
                CurrentTime = Period;
                foreach (Star star in Stars)
                {
                    if (!star.IsActive)
                    {
                        int count = StartPoints.Count;
                        int start1 = Random.Range(0, count);
                        int start2 = (start1 + 1) % count;
                        int end1 = (start2 + 1) % count;
                        int end2 = (end1 + 1) % count;

                        var minStart = StartPoints[start1].position;
                        var maxStart = StartPoints[start2].position;
                        var minEnd = StartPoints[end1].position;
                        var maxEnd = StartPoints[end2].position;
                        var start = new Vector3(Random.Range(minStart.x, maxStart.x), Random.Range(minStart.y, maxStart.y), Random.Range(minStart.z, maxStart.z));
                        var end = new Vector3(Random.Range(minEnd.x, maxEnd.x), Random.Range(minEnd.y, maxEnd.y), Random.Range(minEnd.z, maxEnd.z));

                        star.StartFlight(start, end);
                        break;
                    }
                }
            }
        }
    }
}
