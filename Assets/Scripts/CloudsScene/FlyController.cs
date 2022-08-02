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
    private float CurrentCameraRotSpeed;

    private float RollValue = 0.0f;

    public float MinDelayAfterPress = 1.5f;
    private float DelayAfterPress = 0;

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

            CurrentCameraRotSpeed -= Time.deltaTime * CameraRotationSpeed;
            RollValue += Time.deltaTime * RollSpeed;
            DelayAfterPress = MinDelayAfterPress;
        }
        else if(Input.GetKey(KeyCode.D))
        {
            targetRoll = -TargetRoll;

            CurrentCameraRotSpeed += Time.deltaTime * CameraRotationSpeed;
            RollValue -= Time.deltaTime * RollSpeed;
            DelayAfterPress = MinDelayAfterPress;
        }
        else
        {
            CurrentCameraRotSpeed += CurrentCameraRotSpeed > 0 ? -(Time.deltaTime * CameraRotationSpeedDamping) : Time.deltaTime * CameraRotationSpeedDamping;
            RollValue = RollValue > 0 ? RollValue - Time.deltaTime : RollValue + Time.deltaTime;
            //RollValue -= Time.deltaTime;
        }

        RollValue = Mathf.Clamp(RollValue, -1.0f, 1.0f);
        print(RollValue);
        CurrentCameraRotSpeed = Mathf.Clamp(CurrentCameraRotSpeed, -MaxCameraRotationSpeed, MaxCameraRotationSpeed);
        Camera.transform.Rotate(Vector3.up, CurrentCameraRotSpeed);

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
        rot.z = TargetRoll * RollValue;

        transform.rotation = Quaternion.Euler(rot);

        //transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.Euler(rot), Time.deltaTime * RollSpeed);
    }
}
