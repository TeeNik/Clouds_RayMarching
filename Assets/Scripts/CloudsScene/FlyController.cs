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
    public float PitchOffset = 10.0f;
    public float PitchSpeed = 5.0f;
    
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

    private float RollValue = 0.0f;
    private float PitchValue = 0.0f;

    private void Start()
    {
        InitialPos = transform.localPosition;
    }

    void Update()
    {
        Vector3 dist = Camera.transform.forward * Time.deltaTime * CameraMovementSpeed;
        Camera.transform.position += dist;
        Cube.transform.position += dist;

        if (Input.GetKey(KeyCode.A))
        {
            RollValue += Time.deltaTime * RollSpeed;
        }
        else if(Input.GetKey(KeyCode.D))
        {
            RollValue -= Time.deltaTime * RollSpeed;
        }
        else
        {
            RollValue = RollValue > 0 ? RollValue - Time.deltaTime : RollValue + Time.deltaTime;
        }

        RollValue = Mathf.Clamp(RollValue, -1.0f, 1.0f);
        float currentCameraRotSpeed = -RollValue * MaxCameraRotationSpeed;
        Camera.transform.Rotate(Vector3.up, currentCameraRotSpeed);

        if ( Input.GetKey(KeyCode.W))
        {
            PitchValue += Time.deltaTime * PitchSpeed ;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            PitchValue -= Time.deltaTime * PitchSpeed;
        }
        else
        {
            PitchValue = PitchValue > 0 ? PitchValue - Time.deltaTime : PitchValue + Time.deltaTime;
        }

        RadiusOffset += Time.deltaTime * VerticalSpeed * PitchValue;
        PitchValue = Mathf.Clamp(PitchValue, -1.0f, 1.0f);
        RadiusOffset = Mathf.Clamp(RadiusOffset, -MaxVerticalOffset, MaxVerticalOffset);

        transform.localPosition = InitialPos - Vector3.up * RadiusOffset;

        Vector3 rot = transform.eulerAngles;
        rot.x = DefaultPitch + PitchValue * PitchOffset;
        rot.z = TargetRoll * RollValue;

        transform.rotation = Quaternion.Euler(rot);
    }
}