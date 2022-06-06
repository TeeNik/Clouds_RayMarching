using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Star : MonoBehaviour
{
    [Header("Settings")]
    public int Amount = 17;
    public float Radius = 20.0f;
    public float FirefliesSpeed = 2.0f;
    public float StarRotationSpeed = 100.0f;
    public float MovementOffset = 0.2f;

    public float Speed;

    [Header("Refereces")]
    public GameObject FireflyPrefab;
    public Transform StarObject;

    public bool IsActive { get; private set; }

    private Transform[] Objects;
    private Vector3 InitialPos;
    private Vector3 Velocity;
    private float EndY;


    public void StartFlight(Vector3 start, Vector3 end)
    {
        gameObject.SetActive(true);
        IsActive = true;

        Velocity = (end - start).normalized * Speed;
        EndY = end.y;
        transform.position = start;
        transform.forward = Velocity.normalized;
    }

    void Start()
    {
        InitialPos = transform.position;
        Objects = new Transform[Amount];
        for (int i = 0; i < Amount; ++i)
        {
            Objects[i] = Instantiate(FireflyPrefab, transform).transform;
        }
    }

    void Update()
    {
        if(IsActive)
        {
            transform.position += Velocity * Time.deltaTime;

            for (int i = 0; i < Objects.Length; ++i)
            {
                Transform sphere = Objects[i];
                sphere.localPosition = GetSphereDir(i);
            }

            StarObject.Rotate(StarObject.forward, Time.deltaTime * StarRotationSpeed);
            //transform.position = InitialPos + Vector3.up * MovementOffset * Mathf.Sin(Time.time);

            if(transform.position.y < EndY)
            {
                IsActive = false;
                gameObject.SetActive(false);
            }
        }
    }

    private float rand1dTo1d(float value, float mutator = 0.546f)
    {
        float random = (Mathf.Sin(value + mutator) * 143758.5453f) % 1;
        return random;
    }

    private Vector3 rand1dTo3d(float value)
    {
        return new Vector3(
            rand1dTo1d(value, 3.9812f),
            rand1dTo1d(value, 7.1536f),
            rand1dTo1d(value, 5.7241f)
            );
    }

    private Vector3 GetSphereDir(int id)
    {
        Vector3 baseDir = Vector3.Normalize(rand1dTo3d(id) - Vector3.one * 0.5f) * (rand1dTo1d(id) * 0.9f + 0.1f);
        Vector3 orthogonal = Vector3.Normalize(Vector3.Cross(baseDir, rand1dTo3d(id + 7.1393f) - Vector3.one * 0.5f)) * (rand1dTo1d(id + 3.7443f) * 0.9f + 0.1f); ;
        float scaledTime = Time.time * FirefliesSpeed + rand1dTo1d(id) * 845.12547f;
        Vector3 dir = baseDir * Mathf.Sin(scaledTime) + orthogonal * Mathf.Cos(scaledTime);
        return dir * Radius;
    }
}
