using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AutoRotate : MonoBehaviour
{
    public bool isRotate = true;

    [Range(0.0f, 20.0f)]
    public float rotateSpeed = 1.0f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (isRotate)
            transform.Rotate(new Vector3(0, 1, 0), Mathf.PI / 18 * rotateSpeed);
    }
}
