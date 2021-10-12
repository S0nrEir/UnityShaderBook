using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 雾效后处理
/// </summary>
public class FogWithDepthTex : PostEffectBase
{

    private void OnEnable ()
    {
        _camera = GetComponent<Camera>();
        if (_camera != null)
        {
            _camera.depthTextureMode |= DepthTextureMode.Depth;
            _fov = _camera.fieldOfView;
            _near = _camera.nearClipPlane;
            _far = _camera.farClipPlane;
            _aspect = _camera.aspect;
        }

        //_cachedTransform = transform;
    }

    private void OnRenderImage (RenderTexture source, RenderTexture destination)
    {
        if (FogMaterial is null)
        {
            Graphics.Blit( source, destination );
            return;
        }

        //单位矩阵
        Matrix4x4 frustumCorners = Matrix4x4.identity;
        float halfHeight = _near * Mathf.Tan( _fov * .5f * Mathf.Deg2Rad );
        Vector3 toRight = transform.right * halfHeight * _aspect;
        Vector3 toTop = transform.up * halfHeight;

        //计算近裁面四个角对应的向量，然后把结果传给shader
        var topLeft     = GetDegree( 1, toRight, toTop );
        var topRight    = GetDegree( 2, toRight, toTop );
        var bottomLeft  = GetDegree( 3, toRight, toTop );
        var bottomRight = GetDegree( 4, toRight, toTop );

        frustumCorners.SetRow( 0, bottomLeft );
        frustumCorners.SetRow( 1, bottomRight );
        frustumCorners.SetRow( 2, topRight );
        frustumCorners.SetRow( 3, topLeft );

        FogMaterial.SetFloat( "_FogDensity",_fogDensity);
        FogMaterial.SetColor( "_FogColor", _fogColor );
        FogMaterial.SetFloat( "_FogStart", _fogStart );
        FogMaterial.SetFloat( "_FogEnd", _fogEnd );

        Graphics.Blit( source, destination, FogMaterial );
    }

    /// <summary>
    /// 1topLeft 2topRight 3bottomLeft 4bottomRight
    /// </summary>
    private Vector3 GetDegree (int pos,Vector3 toRight,Vector3 toTop)
    {
        var res = Vector3.zero;
        switch(pos)
        {
            case 1:
                res = transform.forward * _near + toTop - toRight;
                break;

            case 2:
                res = transform.forward * _near + toTop + toRight;
                break;

            case 3:
                res = transform.forward * _near - toTop - toRight;
                break;

            case 4:
                res = transform.forward * _near - toTop + toRight;
                break;
        }
        //scale
        res *= res.magnitude / _near;
        res.Normalize();
        return res;
    }

    private float _fov = 0;
    private float _near = 0;
    private float _far = 0;
    private float _aspect = 0;

    /// <summary>
    /// 雾效结束位置
    /// </summary>
    [SerializeField] private float _fogEnd = 2f;

    /// <summary>
    /// 雾效起始位置
    /// </summary>
    [SerializeField] private float _fogStart = 0.0f;

    /// <summary>
    /// 雾色
    /// </summary>
    [SerializeField] private Color _fogColor = Color.white;

    /// <summary>
    /// 雾效浓度
    /// </summary>
    [SerializeField] [Range( .0f, 3f )] private float _fogDensity = 1f;

    private Transform _cachedTransform = null;
    private Camera _camera = null;

    public Material FogMaterial
    {
        get 
        {
            if (_fogMaterial is null)
                _fogMaterial = CheckShaderAndCreateMaterial( _fogShader ,_fogMaterial);

            return _fogMaterial;
        }
    }

    /// <summary>
    /// 雾效材质
    /// </summary>
    private Material _fogMaterial = null;

    /// <summary>
    /// 雾效shader
    /// </summary>
    [SerializeField] private Shader _fogShader;
}
