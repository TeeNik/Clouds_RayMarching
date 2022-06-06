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

    public List<Star> Stars;
    private float CurrentTime;

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
        CurrentTime -= Time.deltaTime;
        if(CurrentTime < 0)
        {
            CurrentTime = Period;
            foreach(Star star in Stars)
            {
                if(!star.IsActive)
                {
                    var minStart = MinStart.position;
                    var maxStart = MaxStart.position;
                    var minEnd = MinEnd.position;
                    var maxEnd = MaxEnd.position;
                    var start = new Vector3(Random.Range(minStart.x, maxStart.x), Random.Range(minStart.y, maxStart.y), Random.Range(minStart.z, maxStart.z));
                    var end = new Vector3(Random.Range(minEnd.x, maxEnd.x), Random.Range(minEnd.y, maxEnd.y), Random.Range(minEnd.z, maxEnd.z));
                    star.StartFlight(start, end);
                    break;
                }
            }
        }
    }
}
