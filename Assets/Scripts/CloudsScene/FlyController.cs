using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FlyController : MonoBehaviour
{
    public float Radius = 3;
    public float DefaultAngle = -90;
    public float MaxOffset = 30;
    public float Speed = 10;

    private float AngleOffset;

    void Update()
    {
        if(Input.GetKey(KeyCode.A))
        {
            AngleOffset -= Time.deltaTime * Speed;
        }
        else if(Input.GetKey(KeyCode.D))
        {
            AngleOffset += Time.deltaTime * Speed;
        }

        AngleOffset = Mathf.Clamp(AngleOffset, -MaxOffset, MaxOffset);
        float angle = DefaultAngle + AngleOffset;

        float x = Radius * Mathf.Cos(Mathf.Deg2Rad * angle);
        float y = Radius * Mathf.Sin(Mathf.Deg2Rad * angle);
        transform.position = new Vector3(x, y, transform.position.z);

        Vector3 rot = transform.eulerAngles;
        rot.z = AngleOffset;
        transform.eulerAngles = rot;
    }
}
