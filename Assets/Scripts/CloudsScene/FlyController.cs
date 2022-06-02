using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FlyController : MonoBehaviour
{
    public float Radius = 3;
    public float DefaultAngle = -90;
    public float MaxOffset = 30;
    public float Speed = 10;

    public float MaxRadiusOffset = 1;
    public float VerticalSpeed = 20;

    private float DefaultRotZ = 10;

    private float AngleOffset;
    private Vector3 InitialPos;
    private float RadiusOffset;

    private void Start()
    {
        InitialPos = transform.position;
    }

    void Update()
    {
        float targetZRot = DefaultRotZ;
        float prevRadiusOffset = RadiusOffset;

        if(Input.GetKey(KeyCode.A))
        {
            AngleOffset -= Time.deltaTime * Speed;
        }
        else if(Input.GetKey(KeyCode.D))
        {
            AngleOffset += Time.deltaTime * Speed;
        }
        if( Input.GetKey(KeyCode.W))
        {
            RadiusOffset += Time.deltaTime * VerticalSpeed;
            targetZRot = 0;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            RadiusOffset -= Time.deltaTime * VerticalSpeed;
            targetZRot = 20;
        }

        AngleOffset = Mathf.Clamp(AngleOffset, -MaxOffset, MaxOffset);
        float angle = DefaultAngle + AngleOffset;

        RadiusOffset = Mathf.Clamp(RadiusOffset, -MaxRadiusOffset, MaxRadiusOffset);
        float radDiff = Mathf.Abs(Mathf.Abs(RadiusOffset) - MaxRadiusOffset);
        print(radDiff);
        if (radDiff < 0.001)
        {
            targetZRot = DefaultRotZ;
        }

        float radius = Radius + RadiusOffset;

        float x = radius * Mathf.Cos(Mathf.Deg2Rad * angle);
        float y = radius * Mathf.Sin(Mathf.Deg2Rad * angle);
        transform.position = InitialPos + new Vector3(x, y, 0);

        Vector3 rot = transform.eulerAngles;
        rot.x = AngleOffset;
        rot.z = targetZRot;
        transform.rotation = Quaternion.RotateTowards(transform.rotation,
            Quaternion.Euler(rot), Time.deltaTime * Speed);
        //transform.eulerAngles = rot;
    }
}
