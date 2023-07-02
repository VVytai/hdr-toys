// ITU-R BT.2390 EETF
// https://www.itu.int/pub/R-REP-BT.2390

//!PARAM L_hdr
//!TYPE float
//!MINIMUM 0
//!MAXIMUM 10000
1000.0

//!PARAM L_sdr
//!TYPE float
//!MINIMUM 0
//!MAXIMUM 1000
203.0

//!PARAM CONTRAST_sdr
//!TYPE float
//!MINIMUM 0
//!MAXIMUM 1000000
1000.0

//!HOOK OUTPUT
//!BIND HOOKED
//!DESC tone mapping (bt.2390)

const float DISPGAMMA = 2.4;
const float L_W = 1.0;
const float L_B = 0.0;

float bt1886_r(float L, float gamma, float Lw, float Lb) {
    float a = pow(pow(Lw, 1.0 / gamma) - pow(Lb, 1.0 / gamma), gamma);
    float b = pow(Lb, 1.0 / gamma) / (pow(Lw, 1.0 / gamma) - pow(Lb, 1.0 / gamma));
    float V = pow(max(L / a, 0.0), 1.0 / gamma) - b;
    return V;
}

float bt1886_f(float V, float gamma, float Lw, float Lb) {
    float a = pow(pow(Lw, 1.0 / gamma) - pow(Lb, 1.0 / gamma), gamma);
    float b = pow(Lb, 1.0 / gamma) / (pow(Lw, 1.0 / gamma) - pow(Lb, 1.0 / gamma));
    float L = a * pow(max(V + b, 0.0), gamma);
    return L;
}

vec3 tone_mapping_clip(vec3 color) {
    color.rgb = vec3(
        bt1886_r(color.r, DISPGAMMA, L_W, L_W / CONTRAST_sdr),
        bt1886_r(color.g, DISPGAMMA, L_W, L_W / CONTRAST_sdr),
        bt1886_r(color.b, DISPGAMMA, L_W, L_W / CONTRAST_sdr)
    );

    color.rgb = vec3(
        bt1886_f(color.r, DISPGAMMA, L_W, L_B),
        bt1886_f(color.g, DISPGAMMA, L_W, L_B),
        bt1886_f(color.b, DISPGAMMA, L_W, L_B)
    );
    return color;
}

const float pq_m1 = 0.1593017578125;
const float pq_m2 = 78.84375;
const float pq_c1 = 0.8359375;
const float pq_c2 = 18.8515625;
const float pq_c3 = 18.6875;

const float pq_C  = 10000.0;

float Y_to_ST2084(float C) {
    float L = C / pq_C;
    float Lm = pow(L, pq_m1);
    float N = (pq_c1 + pq_c2 * Lm) / (1.0 + pq_c3 * Lm);
    N = pow(N, pq_m2);
    return N;
}

float ST2084_to_Y(float N) {
    float Np = pow(N, 1.0 / pq_m2);
    float L = Np - pq_c1;
    if (L < 0.0 ) L = 0.0;
    L = L / (pq_c2 - pq_c3 * Np);
    L = pow(L, 1.0 / pq_m1);
    return L * pq_C;
}

vec3 RGB_to_XYZ(vec3 RGB) {
    mat3 M = mat3(
        0.6369580483012914, 0.14461690358620832,  0.1688809751641721,
        0.2627002120112671, 0.6779980715188708,   0.05930171646986196,
        0.000000000000000,  0.028072693049087428, 1.060985057710791);
    return RGB * M;
}

vec3 XYZ_to_RGB(vec3 XYZ) {
    mat3 M = mat3(
         1.716651187971268,  -0.355670783776392, -0.253366281373660,
        -0.666684351832489,   1.616481236634939,  0.0157685458139111,
         0.017639857445311,  -0.042770613257809,  0.942103121235474);
    return XYZ * M;
}

vec3 XYZ_to_LMS(vec3 XYZ) {
    mat3 M = mat3(
         0.3592, 0.6976, -0.0358,
        -0.1922, 1.1004,  0.0755,
         0.0070, 0.0749,  0.8434);
    return XYZ * M;
}

vec3 LMS_to_XYZ(vec3 LMS) {
    mat3 M = mat3(
         2.070180056695613509600, -1.326456876103021025500,  0.206616006847855170810,
         0.364988250032657479740,  0.680467362852235141020, -0.045421753075853231409,
        -0.049595542238932107896, -0.049421161186757487412,  1.187995941732803439400);
    return LMS * M;
}

vec3 LMS_to_ICtCp(vec3 LMS) {
    LMS.x = Y_to_ST2084(LMS.x);
    LMS.y = Y_to_ST2084(LMS.y);
    LMS.z = Y_to_ST2084(LMS.z);
    mat3 M = mat3(
         2048,   2048,    0,
         6610, -13613, 7003,
        17933, -17390, -543) / 4096;
    return LMS * M;
}

vec3 ICtCp_to_LMS(vec3 ICtCp) {
    mat3 M = mat3(
        0.99998889656284013833,  0.00860505014728705821,  0.11103437159861647860,
        1.00001110343715986160, -0.00860505014728705821, -0.11103437159861647860,
        1.00003206339100541200,  0.56004913547279000113, -0.32063391005412026469);
    ICtCp *= M;
    ICtCp.x = ST2084_to_Y(ICtCp.x);
    ICtCp.y = ST2084_to_Y(ICtCp.y);
    ICtCp.z = ST2084_to_Y(ICtCp.z);
    return ICtCp;
}

vec3 RGB_to_Ictcp(vec3 color, float L_sdr) {
    color *= L_sdr;
    color = RGB_to_XYZ(color);
    color = XYZ_to_LMS(color);
    color = LMS_to_ICtCp(color);
    return color;
}

vec3 Ictcp_to_RGB(vec3 color, float L_sdr) {
    color = ICtCp_to_LMS(color);
    color = LMS_to_XYZ(color);
    color = XYZ_to_RGB(color);
    color /= L_sdr;
    return color;
}

float f(float x, float L_w, float L_b, float L_max, float L_min) {
    const float maxLum = (L_max - L_b) / (L_w - L_b);
    const float minLum = (L_min - L_b) / (L_w - L_b);

    const float KS = 1.5 * maxLum - 0.5;
    const float b = minLum;

    // E1
    x = (x - L_b) / (L_w - L_b);

    // E2
    if (KS <= x) {
        const float TB  = (x - KS) / (1.0 - KS);
        const float TB2 = TB * TB;
        const float TB3 = TB * TB2;

        const float PB  = (2.0 * TB3 - 3.0 * TB2 + 1.0) * KS  +
                          (TB3 - 2.0 * TB2 + TB) * (1.0 - KS) +
                          (-2.0 * TB3 + 3.0 * TB2) * maxLum;

        x = PB;
    }

    // E3
    if (0.0 <= x) {
        x = x + b * pow((1 - x), 4.0);
    }

    // E4
    x = x * (L_w - L_b) + L_b;

    return x;
}

vec3 tone_mapping(vec3 Ictcp) {
    const float iw = Y_to_ST2084(L_hdr);
    const float ib = Y_to_ST2084(0.0);
    const float ow = Y_to_ST2084(L_sdr);
    const float ob = Y_to_ST2084(L_sdr / CONTRAST_sdr);

    float I2  = f(Ictcp.x, iw, ib, ow, ob);
    Ictcp.yz *= min(Ictcp.x / I2, I2 / Ictcp.x);
    Ictcp.x   = I2;

    return Ictcp;
}

vec4 color = HOOKED_tex(HOOKED_pos);
vec4 hook() {
    color.rgb = RGB_to_Ictcp(color.rgb, L_sdr);
    color.rgb = tone_mapping(color.rgb);
    color.rgb = Ictcp_to_RGB(color.rgb, L_sdr);
    color.rgb = tone_mapping_clip(color.rgb);
    return color;
}
