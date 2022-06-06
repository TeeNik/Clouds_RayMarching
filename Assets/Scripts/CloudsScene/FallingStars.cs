using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FallingStars : MonoBehaviour
{

    public GameObject StarPrefab;
    public int Amount = 1;

    public Vector3 MinStart;
    public Vector3 MaxStart;
    public Vector3 MinEnd;
    public Vector3 MaxEnd;

    public float Period = 5.0f;

    private Transform[] Stars;
    private bool[] StarsAvailable;
    private float CurrentTime;

    void Start()
    {
        Stars = new Transform[Amount];
        StarsAvailable = new bool[Amount];
    }

    void Update()
    {
        CurrentTime += Time.deltaTime;
    }
}
