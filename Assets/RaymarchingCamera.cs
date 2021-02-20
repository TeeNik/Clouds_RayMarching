using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchingCamera : SceneViewFilter
{
    [SerializeField] private Shader _shader;

    public Material RaymarchingMaterial;


    //private Material _raymarchingMaterial;
    //public Material RaymarchingMaterial
    //{
    //    get
    //    {
    //        if (!_raymarchingMaterial && _shader)
    //        {
    //            _raymarchingMaterial = new Material(_shader);
    //            _raymarchingMaterial.hideFlags = HideFlags.HideAndDontSave;
    //        }
    //        return _raymarchingMaterial;
    //    }
    //}

    private Camera _camera;
    public Camera Camera
    {
        get
        {
            if (!_camera)
            {
                _camera = GetComponent<Camera>();
            }
            return _camera;
        }
    }

    public float MaxDistance;

    public Transform Sphere;
    public Transform Box;
    public Transform Torus;

    public Transform DirectionalLight;
    public Color MainColor;
    public Vector3 ModInterval;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!RaymarchingMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }

        RaymarchingMaterial.SetMatrix("_CamFrustum", CamFrustum(Camera));
        RaymarchingMaterial.SetMatrix("_CamToWorld", Camera.cameraToWorldMatrix);
        RaymarchingMaterial.SetFloat("_MaxDistance", MaxDistance);

        RaymarchingMaterial.SetVector("_Sphere", Sphere ? new Vector4(Sphere.localPosition.x, Sphere.localPosition.y, Sphere.localPosition.z, Sphere.localScale.x) : Vector4.one);
        RaymarchingMaterial.SetVector("_Box", Box ? new Vector4(Box.position.x, Box.position.y, Box.position.z, Box.localScale.x) : Vector4.one);
        RaymarchingMaterial.SetVector("_Torus", Torus ? new Vector4(Torus.position.x, Torus.position.y, Torus.position.z, Torus.localScale.x) : Vector4.one);

        RaymarchingMaterial.SetVector("_LightDir", DirectionalLight ? DirectionalLight.forward : Vector3.down);
        RaymarchingMaterial.SetColor("_MainColor", MainColor);
        RaymarchingMaterial.SetVector("_ModInterval", ModInterval);

        Matrix4x4 rotMatrix = Matrix4x4.TRS(
            Vector3.one,
            Quaternion.Euler(new Vector3(0, (Time.time * 100) % 360, (Time.time * 100) % 360)), 
            Vector3.one
            );

        RaymarchingMaterial.SetMatrix("_RotationMat", rotMatrix.inverse);
        

        RenderTexture.active = destination;
        RaymarchingMaterial.SetTexture("_MainTex", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        RaymarchingMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //bottom left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //bottom right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //top right
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //top left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 topLeft = -Vector3.forward - goRight + goUp;
        Vector3 topRight = -Vector3.forward + goRight + goUp;
        Vector3 bottomLeft = -Vector3.forward - goRight - goUp;
        Vector3 bottomRight = -Vector3.forward + goRight - goUp;

        frustum.SetRow(0, topLeft);
        frustum.SetRow(1, topRight);
        frustum.SetRow(2, bottomRight);
        frustum.SetRow(3, bottomLeft);

        return frustum;
    }

}
