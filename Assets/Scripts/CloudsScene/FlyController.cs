using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FlyController : MonoBehaviour
{
    [Header("Glider")]
    public float RollSpeed = 45;
    public float MaxVerticalOffset = 0.05f;
    public float VerticalSpeed = 20;
    public float DefaultPitch = -10.0f;
    public float MaxPitch = 0.0f;
    public float MinPitch = -20.0f;
    public float TargetRoll = 30.0f;

    [Header("Camera")]
    public Transform Camera;
    public float CameraMovementSpeed = 0.2f;
    public float CameraRotationSpeed = 1.0f;
    public float MaxCameraRotationSpeed = 0.1f;
    public float CameraRotationSpeedDamping = 0.25f;
    public Transform Cube;

    private Vector3 InitialPos;
    private float RadiusOffset;
    private float CurremtCameraRotSpeed;

    private void Start()
    {
        InitialPos = transform.localPosition;
    }

    void Update()
    {
        float targetRoll = 0;
        float targetPitch = DefaultPitch;

        Vector3 dist = Camera.transform.forward * Time.deltaTime * CameraMovementSpeed;
        Camera.transform.position += dist;
        Cube.transform.position += dist;

        if (Input.GetKey(KeyCode.A))
        {
            targetRoll = TargetRoll;

            CurremtCameraRotSpeed -= Time.deltaTime * CameraRotationSpeed;
        }
        else if(Input.GetKey(KeyCode.D))
        {
            targetRoll = -TargetRoll;

            CurremtCameraRotSpeed += Time.deltaTime * CameraRotationSpeed;
        }
        else
        {
            CurremtCameraRotSpeed += CurremtCameraRotSpeed > 0 ? -(Time.deltaTime * CameraRotationSpeedDamping) : Time.deltaTime * CameraRotationSpeedDamping;  
        }

        CurremtCameraRotSpeed = Mathf.Clamp(CurremtCameraRotSpeed, -MaxCameraRotationSpeed, MaxCameraRotationSpeed);
        Camera.transform.Rotate(Vector3.up, CurremtCameraRotSpeed);

        if ( Input.GetKey(KeyCode.W))
        {
            RadiusOffset += Time.deltaTime * VerticalSpeed;
            targetPitch = MaxPitch;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            RadiusOffset -= Time.deltaTime * VerticalSpeed;
            targetPitch = MinPitch;
        }


        RadiusOffset = Mathf.Clamp(RadiusOffset, -MaxVerticalOffset, MaxVerticalOffset);
        float radDiff = Mathf.Abs(Mathf.Abs(RadiusOffset) - MaxVerticalOffset);
        if (radDiff < 0.001)
        {
            targetPitch = DefaultPitch;
        }

        transform.localPosition = InitialPos - Vector3.up * RadiusOffset;

        Vector3 rot = transform.eulerAngles;
        rot.x = targetPitch;
        rot.z = targetRoll;

        transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.Euler(rot), Time.deltaTime * RollSpeed);
    }
}
