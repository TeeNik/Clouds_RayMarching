using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Balloon : MonoBehaviour
{
    public float MinSpeed = 0.1f; 
    public float MaxSpeed = 0.3f;

    public Vector3 MinBound;
    public Vector3 MaxBound;

    public Texture2D[] Textures;

    public bool IsActive { get; private set; }

    private float Speed;

    public void StartFlight(Transform player)
    {
        IsActive = true;
        Speed = Random.Range(MinSpeed, MaxSpeed);

        float dist = Random.Range(MinBound.z, MaxBound.z);
        Vector3 pos = player.transform.position + player.transform.forward * dist;
        pos.y = MinBound.y;
        Vector3 side = Random.Range(0, 2) > 0 ? player.right : -player.right;
        pos += side * Random.Range(MinBound.x, MaxBound.y);
        transform.position = pos;

        var texture = Textures[Random.Range(0, Textures.Length)];
        GetComponent<MeshRenderer>().material.SetTexture("_MainTex", texture);
    }

    void Update()
    {
        if(IsActive)
        {
            transform.position += Vector3.up * Speed * Time.deltaTime;
            if(transform.position.y > MaxBound.y)
            {
                IsActive=false;
            }
        }
    }
}
