#include "cuda_helper.h"

__device__ __constant__ uint64_t const keccak_round_constants[24] = {
	0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL,
	0x8000000080008000ULL, 0x000000000000808BULL, 0x0000000080000001ULL,
	0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008AULL,
	0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
	0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL,
	0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
	0x000000000000800AULL, 0x800000008000000AULL, 0x8000000080008081ULL,
	0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

__device__ __forceinline__
uint64_t xor5(const uint64_t a, const uint64_t b, const uint64_t c, const uint64_t d, const uint64_t e) {
	return a ^ b ^ c ^ d ^ e;
}
__device__ __forceinline__
uint64_t xor3(const uint64_t a, const uint64_t b, const uint64_t c) {
	return a ^ b ^ c;
}

__device__ __forceinline__
uint64_t chi(const uint64_t a, const uint64_t b, const uint64_t c) {
	return a ^ (~b) & c;
}

__device__ __forceinline__ void keccak_f1600_init(uint64_t * s)
{
	uint64_t t[5], u, v;

	devectorize4(d_header.uint4s[0], s[0], s[1]);
	devectorize4(d_header.uint4s[1], s[2], s[3]);

	for (uint32_t i = 5; i < 25; i++)
	{
		s[i] = 0;
	}
	s[5] = 0x0000000000000001;
	s[8] = 0x8000000000000000;

	/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
	t[0] = s[0] ^ s[5];
	t[1] = s[1];
	t[2] = s[2];
	t[3] = s[3] ^ s[8];
	t[4] = s[4];

	/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
	/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

	u = ROTL64(t[1], 1);
	s[0] = xor3(s[0], t[4], u);
	s[5] = xor3(s[5], t[4], u);
	s[10] = xor3(s[10], t[4], u);
	s[15] = xor3(s[15], t[4], u);
	s[20] = xor3(s[20], t[4], u);

	u = ROTL64(t[2], 1);
	s[1] = xor3(s[1], t[0], u);
	s[6] = xor3(s[6], t[0], u);
	s[11] = xor3(s[11], t[0], u);
	s[16] = xor3(s[16], t[0], u);
	s[21] = xor3(s[21], t[0], u);

	u = ROTL64(t[3], 1);
	s[2] = xor3(s[2], t[1], u);
	s[7] = xor3(s[7], t[1], u);
	s[12] = xor3(s[12], t[1], u);
	s[17] = xor3(s[17], t[1], u);
	s[22] = xor3(s[22], t[1], u);

	u = ROTL64(t[4], 1);
	s[3] = xor3(s[3], t[2], u);
	s[8] = xor3(s[8], t[2], u);
	s[13] = xor3(s[13], t[2], u);
	s[18] = xor3(s[18], t[2], u);
	s[23] = xor3(s[23], t[2], u);

	u = ROTL64(t[0], 1);
	s[4] = xor3(s[4], t[3], u);
	s[9] = xor3(s[9], t[3], u);
	s[14] = xor3(s[14], t[3], u);
	s[19] = xor3(s[19], t[3], u);
	s[24] = xor3(s[24], t[3], u);

	/* rho pi: b[..] = rotl(a[..], ..) */
	u = s[1];

	s[1] = ROTL64(s[6], 44);
	s[6] = ROTL64(s[9], 20);
	s[9] = ROTL64(s[22], 61);
	s[22] = ROTL64(s[14], 39);
	s[14] = ROTL64(s[20], 18);
	s[20] = ROTL64(s[2], 62);
	s[2] = ROTL64(s[12], 43);
	s[12] = ROTL64(s[13], 25);
	s[13] = ROTL64(s[19], 8);
	s[19] = ROTL64(s[23], 56);
	s[23] = ROTL64(s[15], 41);
	s[15] = ROTL64(s[4], 27);
	s[4] = ROTL64(s[24], 14);
	s[24] = ROTL64(s[21], 2);
	s[21] = ROTL64(s[8], 55);
	s[8] = ROTL64(s[16], 45);
	s[16] = ROTL64(s[5], 36);
	s[5] = ROTL64(s[3], 28);
	s[3] = ROTL64(s[18], 21);
	s[18] = ROTL64(s[17], 15);
	s[17] = ROTL64(s[11], 10);
	s[11] = ROTL64(s[7], 6);
	s[7] = ROTL64(s[10], 3);
	s[10] = ROTL64(u, 1);

	/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */

	u = s[0]; v = s[1];
	s[0] = chi(s[0], s[1], s[2]);
	s[1] = chi(s[1], s[2], s[3]);
	s[2] = chi(s[2], s[3], s[4]);
	s[3] = chi(s[3], s[4], u);
	s[4] = chi(s[4], u, v);

	u = s[5]; v = s[6];
	s[5] = chi(s[5], s[6], s[7]);
	s[6] = chi(s[6], s[7], s[8]);
	s[7] = chi(s[7], s[8], s[9]);
	s[8] = chi(s[8], s[9], u);
	s[9] = chi(s[9], u, v);

	u = s[10]; v = s[11];
	s[10] = chi(s[10], s[11], s[12]);
	s[11] = chi(s[11], s[12], s[13]);
	s[12] = chi(s[12], s[13], s[14]);
	s[13] = chi(s[13], s[14], u);
	s[14] = chi(s[14], u, v);

	u = s[15]; v = s[16];
	s[15] = chi(s[15], s[16], s[17]);
	s[16] = chi(s[16], s[17], s[18]);
	s[17] = chi(s[17], s[18], s[19]);
	s[18] = chi(s[18], s[19], u);
	s[19] = chi(s[19], u, v);

	u = s[20]; v = s[21];
	s[20] = chi(s[20], s[21], s[22]);
	s[21] = chi(s[21], s[22], s[23]);
	s[22] = chi(s[22], s[23], s[24]);
	s[23] = chi(s[23], s[24], u);
	s[24] = chi(s[24], u, v);

	/* iota: a[0,0] ^= round constant */
	s[0] ^= keccak_round_constants[0];

	for (int i = 1; i < 23; i++)
	{
		/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
		t[0] = xor5(s[0] , s[5] , s[10] , s[15] , s[20]);
		t[1] = xor5(s[1] , s[6] , s[11] , s[16] , s[21]);
		t[2] = xor5(s[2] , s[7] , s[12] , s[17] , s[22]);
		t[3] = xor5(s[3] , s[8] , s[13] , s[18] , s[23]);
		t[4] = xor5(s[4] , s[9] , s[14] , s[19] , s[24]);

		/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
		/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

		u = ROTL64(t[1], 1);
		s[0]  = xor3(s[0], t[4], u);
		s[5]  = xor3(s[5], t[4], u);
		s[10] = xor3(s[10], t[4], u);
		s[15] = xor3(s[15], t[4], u);
		s[20] = xor3(s[20], t[4], u);

		u = ROTL64(t[2], 1);
		s[1] = xor3(s[1], t[0], u);
		s[6] = xor3(s[6], t[0], u);
		s[11] = xor3(s[11], t[0], u);
		s[16] = xor3(s[16], t[0], u);
		s[21] = xor3(s[21], t[0], u);

		u = ROTL64(t[3], 1);
		s[2] = xor3(s[2], t[1], u);
		s[7] = xor3(s[7], t[1], u);
		s[12] = xor3(s[12], t[1], u);
		s[17] = xor3(s[17], t[1], u);
		s[22] = xor3(s[22], t[1], u);

		u = ROTL64(t[4], 1);
		s[3] = xor3(s[3], t[2], u);
		s[8] = xor3(s[8], t[2], u);
		s[13] = xor3(s[13], t[2], u);
		s[18] = xor3(s[18], t[2], u);
		s[23] = xor3(s[23], t[2], u);


		u = ROTL64(t[0], 1);
		s[4] = xor3(s[4], t[3], u);
		s[9] = xor3(s[9], t[3], u);
		s[14] = xor3(s[14], t[3], u);
		s[19] = xor3(s[19], t[3], u);
		s[24] = xor3(s[24], t[3], u);

		/* rho pi: b[..] = rotl(a[..], ..) */
		u = s[1];

		s[1] = ROTL64(s[6], 44);
		s[6] = ROTL64(s[9], 20);
		s[9] = ROTL64(s[22], 61);
		s[22] = ROTL64(s[14], 39);
		s[14] = ROTL64(s[20], 18);
		s[20] = ROTL64(s[2], 62);
		s[2] = ROTL64(s[12], 43);
		s[12] = ROTL64(s[13], 25);
		s[13] = ROTL64(s[19], 8);
		s[19] = ROTL64(s[23], 56);
		s[23] = ROTL64(s[15], 41);
		s[15] = ROTL64(s[4], 27);
		s[4] = ROTL64(s[24], 14);
		s[24] = ROTL64(s[21], 2);
		s[21] = ROTL64(s[8], 55);
		s[8] = ROTL64(s[16], 45);
		s[16] = ROTL64(s[5], 36);
		s[5] = ROTL64(s[3], 28);
		s[3] = ROTL64(s[18], 21);
		s[18] = ROTL64(s[17], 15);
		s[17] = ROTL64(s[11], 10);
		s[11] = ROTL64(s[7], 6);
		s[7] = ROTL64(s[10], 3);
		s[10] = ROTL64(u, 1);

		/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */
			
		u = s[0]; v = s[1];
		s[0] = chi(s[0], s[1], s[2]);
		s[1] = chi(s[1], s[2], s[3]);
		s[2] = chi(s[2], s[3], s[4]);
		s[3] = chi(s[3], s[4], u);
		s[4] = chi(s[4], u, v);

		u = s[5]; v = s[6]; 
		s[5] = chi(s[5], s[6], s[7]);
		s[6] = chi(s[6], s[7], s[8]);
		s[7] = chi(s[7], s[8], s[9]);
		s[8] = chi(s[8], s[9], u);
		s[9] = chi(s[9], u, v);

		u = s[10]; v = s[11]; 
		s[10] = chi(s[10], s[11], s[12]);
		s[11] = chi(s[11], s[12], s[13]);
		s[12] = chi(s[12], s[13], s[14]);
		s[13] = chi(s[13], s[14], u);
		s[14] = chi(s[14], u, v);

		u = s[15]; v = s[16];
		s[15] = chi(s[15], s[16], s[17]);
		s[16] = chi(s[16], s[17], s[18]);
		s[17] = chi(s[17], s[18], s[19]);
		s[18] = chi(s[18], s[19], u);
		s[19] = chi(s[19], u, v);

		u = s[20]; v = s[21];
		s[20] = chi(s[20], s[21], s[22]);
		s[21] = chi(s[21], s[22], s[23]);
		s[22] = chi(s[22], s[23], s[24]);
		s[23] = chi(s[23], s[24], u);
		s[24] = chi(s[24], u, v);

		/* iota: a[0,0] ^= round constant */
		s[0] ^= keccak_round_constants[i];
	}

	/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
	t[0] = xor5(s[0], s[5], s[10], s[15], s[20]);
	t[1] = xor5(s[1], s[6], s[11], s[16], s[21]);
	t[2] = xor5(s[2], s[7], s[12], s[17], s[22]);
	t[3] = xor5(s[3], s[8], s[13], s[18], s[23]);
	t[4] = xor5(s[4], s[9], s[14], s[19], s[24]);

	/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
	/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

	u = ROTL64(t[1], 1);
	s[0] = xor3(s[0], t[4], u);
	s[10] = xor3(s[10], t[4], u);

	u = ROTL64(t[2], 1);
	s[6] = xor3(s[6], t[0], u);
	s[16] = xor3(s[16], t[0], u);

	u = ROTL64(t[3], 1);
	s[12] = xor3(s[12], t[1], u);
	s[22] = xor3(s[22], t[1], u);

	u = ROTL64(t[4], 1);
	s[3] = xor3(s[3], t[2], u);
	s[18] = xor3(s[18], t[2], u);

	u = ROTL64(t[0], 1);
	s[9] = xor3(s[9], t[3], u);
	s[24] = xor3(s[24], t[3], u);

	/* rho pi: b[..] = rotl(a[..], ..) */
	u = s[1];

	s[1] = ROTL64(s[6], 44);
	s[6] = ROTL64(s[9], 20);
	s[9] = ROTL64(s[22], 61);
	s[2] = ROTL64(s[12], 43);
	s[4] = ROTL64(s[24], 14);
	s[8] = ROTL64(s[16], 45);
	s[5] = ROTL64(s[3], 28);
	s[3] = ROTL64(s[18], 21);
	s[7] = ROTL64(s[10], 3);

	/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */

	u = s[0]; v = s[1];
	s[0] = chi(s[0], s[1], s[2]);
	s[1] = chi(s[1], s[2], s[3]);
	s[2] = chi(s[2], s[3], s[4]);
	s[3] = chi(s[3], s[4], u);
	s[4] = chi(s[4], u, v);
	s[5] = chi(s[5], s[6], s[7]);
	s[6] = chi(s[6], s[7], s[8]);
	s[7] = chi(s[7], s[8], s[9]);

	/* iota: a[0,0] ^= round constant */
	s[0] ^= keccak_round_constants[23];
}

__device__ __forceinline__ uint64_t keccak_f1600_final(uint64_t* s)
{
	uint64_t t[5], u, v;

	for (uint32_t i = 12; i < 25; i++)
	{
		s[i] = 0;
	}
	s[12] = 0x0000000000000001;
	s[16] = 0x8000000000000000;
	
	/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
	t[0] = xor3(s[0], s[5], s[10]);
	t[1] = xor3(s[1], s[6], s[11]) ^ s[16];
	t[2] = xor3(s[2], s[7], s[12]);
	t[3] = s[3] ^ s[8];
	t[4] = s[4] ^ s[9];

	/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
	/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

	u = ROTL64(t[1], 1);
	s[0] = xor3(s[0], t[4], u);
	s[5] = xor3(s[5], t[4], u);
	s[10] = xor3(s[10], t[4], u);
	s[15] = xor3(s[15], t[4], u);
	s[20] = xor3(s[20], t[4], u);

	u = ROTL64(t[2], 1);
	s[1] = xor3(s[1], t[0], u);
	s[6] = xor3(s[6], t[0], u);
	s[11] = xor3(s[11], t[0], u);
	s[16] = xor3(s[16], t[0], u);
	s[21] = xor3(s[21], t[0], u);

	u = ROTL64(t[3], 1);
	s[2] = xor3(s[2], t[1], u);
	s[7] = xor3(s[7], t[1], u);
	s[12] = xor3(s[12], t[1], u);
	s[17] = xor3(s[17], t[1], u);
	s[22] = xor3(s[22], t[1], u);

	u = ROTL64(t[4], 1);
	s[3] = xor3(s[3], t[2], u);
	s[8] = xor3(s[8], t[2], u);
	s[13] = xor3(s[13], t[2], u);
	s[18] = xor3(s[18], t[2], u);
	s[23] = xor3(s[23], t[2], u);


	u = ROTL64(t[0], 1);
	s[4] = xor3(s[4], t[3], u);
	s[9] = xor3(s[9], t[3], u);
	s[14] = xor3(s[14], t[3], u);
	s[19] = xor3(s[19], t[3], u);
	s[24] = xor3(s[24], t[3], u);

	/* rho pi: b[..] = rotl(a[..], ..) */
	u = s[1];

	s[1] = ROTL64(s[6], 44);
	s[6] = ROTL64(s[9], 20);
	s[9] = ROTL64(s[22], 61);
	s[22] = ROTL64(s[14], 39);
	s[14] = ROTL64(s[20], 18);
	s[20] = ROTL64(s[2], 62);
	s[2] = ROTL64(s[12], 43);
	s[12] = ROTL64(s[13], 25);
	s[13] = ROTL64(s[19], 8);
	s[19] = ROTL64(s[23], 56);
	s[23] = ROTL64(s[15], 41);
	s[15] = ROTL64(s[4], 27);
	s[4] = ROTL64(s[24], 14);
	s[24] = ROTL64(s[21], 2);
	s[21] = ROTL64(s[8], 55);
	s[8] = ROTL64(s[16], 45);
	s[16] = ROTL64(s[5], 36);
	s[5] = ROTL64(s[3], 28);
	s[3] = ROTL64(s[18], 21);
	s[18] = ROTL64(s[17], 15);
	s[17] = ROTL64(s[11], 10);
	s[11] = ROTL64(s[7], 6);
	s[7] = ROTL64(s[10], 3);
	s[10] = ROTL64(u, 1);

	/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */
	u = s[0]; v = s[1];
	s[0] = chi(s[0], s[1], s[2]);
	s[1] = chi(s[1], s[2], s[3]);
	s[2] = chi(s[2], s[3], s[4]);
	s[3] = chi(s[3], s[4], u);
	s[4] = chi(s[4], u, v);

	u = s[5]; v = s[6];
	s[5] = chi(s[5], s[6], s[7]);
	s[6] = chi(s[6], s[7], s[8]);
	s[7] = chi(s[7], s[8], s[9]);
	s[8] = chi(s[8], s[9], u);
	s[9] = chi(s[9], u, v);

	u = s[10]; v = s[11];
	s[10] = chi(s[10], s[11], s[12]);
	s[11] = chi(s[11], s[12], s[13]);
	s[12] = chi(s[12], s[13], s[14]);
	s[13] = chi(s[13], s[14], u);
	s[14] = chi(s[14], u, v);

	u = s[15]; v = s[16];
	s[15] = chi(s[15], s[16], s[17]);
	s[16] = chi(s[16], s[17], s[18]);
	s[17] = chi(s[17], s[18], s[19]);
	s[18] = chi(s[18], s[19], u);
	s[19] = chi(s[19], u, v);

	u = s[20]; v = s[21];
	s[20] = chi(s[20], s[21], s[22]);
	s[21] = chi(s[21], s[22], s[23]);
	s[22] = chi(s[22], s[23], s[24]);
	s[23] = chi(s[23], s[24], u);
	s[24] = chi(s[24], u, v);

	/* iota: a[0,0] ^= round constant */
	s[0] ^= keccak_round_constants[0];

	for (int i = 1; i < 23; i++)
	{
		/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
		t[0] = xor5(s[0], s[5], s[10], s[15], s[20]);
		t[1] = xor5(s[1], s[6], s[11], s[16], s[21]);
		t[2] = xor5(s[2], s[7], s[12], s[17], s[22]);
		t[3] = xor5(s[3], s[8], s[13], s[18], s[23]);
		t[4] = xor5(s[4], s[9], s[14], s[19], s[24]);

		/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
		/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

		u = ROTL64(t[1], 1);
		s[0] = xor3(s[0], t[4], u);
		s[5] = xor3(s[5], t[4], u);
		s[10] = xor3(s[10], t[4], u);
		s[15] = xor3(s[15], t[4], u);
		s[20] = xor3(s[20], t[4], u);

		u = ROTL64(t[2], 1);
		s[1] = xor3(s[1], t[0], u);
		s[6] = xor3(s[6], t[0], u);
		s[11] = xor3(s[11], t[0], u);
		s[16] = xor3(s[16], t[0], u);
		s[21] = xor3(s[21], t[0], u);

		u = ROTL64(t[3], 1);
		s[2] = xor3(s[2], t[1], u);
		s[7] = xor3(s[7], t[1], u);
		s[12] = xor3(s[12], t[1], u);
		s[17] = xor3(s[17], t[1], u);
		s[22] = xor3(s[22], t[1], u);

		u = ROTL64(t[4], 1);
		s[3] = xor3(s[3], t[2], u);
		s[8] = xor3(s[8], t[2], u);
		s[13] = xor3(s[13], t[2], u);
		s[18] = xor3(s[18], t[2], u);
		s[23] = xor3(s[23], t[2], u);


		u = ROTL64(t[0], 1);
		s[4] = xor3(s[4], t[3], u);
		s[9] = xor3(s[9], t[3], u);
		s[14] = xor3(s[14], t[3], u);
		s[19] = xor3(s[19], t[3], u);
		s[24] = xor3(s[24], t[3], u);

		/* rho pi: b[..] = rotl(a[..], ..) */
		u = s[1];

		s[1] = ROTL64(s[6], 44);
		s[6] = ROTL64(s[9], 20);
		s[9] = ROTL64(s[22], 61);
		s[22] = ROTL64(s[14], 39);
		s[14] = ROTL64(s[20], 18);
		s[20] = ROTL64(s[2], 62);
		s[2] = ROTL64(s[12], 43);
		s[12] = ROTL64(s[13], 25);
		s[13] = ROTL64(s[19], 8);
		s[19] = ROTL64(s[23], 56);
		s[23] = ROTL64(s[15], 41);
		s[15] = ROTL64(s[4], 27);
		s[4] = ROTL64(s[24], 14);
		s[24] = ROTL64(s[21], 2);
		s[21] = ROTL64(s[8], 55);
		s[8] = ROTL64(s[16], 45);
		s[16] = ROTL64(s[5], 36);
		s[5] = ROTL64(s[3], 28);
		s[3] = ROTL64(s[18], 21);
		s[18] = ROTL64(s[17], 15);
		s[17] = ROTL64(s[11], 10);
		s[11] = ROTL64(s[7], 6);
		s[7] = ROTL64(s[10], 3);
		s[10] = ROTL64(u, 1);

		/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */
		u = s[0]; v = s[1];
		s[0] = chi(s[0], s[1], s[2]);	
		s[1] = chi(s[1], s[2], s[3]);
		s[2] = chi(s[2], s[3], s[4]);
		s[3] = chi(s[3], s[4], u);
		s[4] = chi(s[4], u, v);

		u = s[5]; v = s[6];
		s[5] = chi(s[5], s[6], s[7]);
		s[6] = chi(s[6], s[7], s[8]);
		s[7] = chi(s[7], s[8], s[9]);
		s[8] = chi(s[8], s[9], u);
		s[9] = chi(s[9], u, v);

		u = s[10]; v = s[11];
		s[10] = chi(s[10], s[11], s[12]);
		s[11] = chi(s[11], s[12], s[13]);
		s[12] = chi(s[12], s[13], s[14]);
		s[13] = chi(s[13], s[14], u);
		s[14] = chi(s[14], u, v);

		u = s[15]; v = s[16];
		s[15] = chi(s[15], s[16], s[17]);
		s[16] = chi(s[16], s[17], s[18]);
		s[17] = chi(s[17], s[18], s[19]);
		s[18] = chi(s[18], s[19], u);
		s[19] = chi(s[19], u, v);

		u = s[20]; v = s[21];
		s[20] = chi(s[20], s[21], s[22]);
		s[21] = chi(s[21], s[22], s[23]);
		s[22] = chi(s[22], s[23], s[24]);
		s[23] = chi(s[23], s[24], u);
		s[24] = chi(s[24], u, v);

		/* iota: a[0,0] ^= round constant */
		s[0] ^= keccak_round_constants[i];
	}

	t[0] = xor5(s[0], s[5], s[10], s[15], s[20]);
	t[1] = xor5(s[1], s[6], s[11], s[16], s[21]);
	t[2] = xor5(s[2], s[7], s[12], s[17], s[22]);
	t[3] = xor5(s[3], s[8], s[13], s[18], s[23]);
	t[4] = xor5(s[4], s[9], s[14], s[19], s[24]);

	s[0] = xor3(s[0], t[4], ROTL64(t[1], 1));
	s[6] = xor3(s[6], t[0], ROTL64(t[2], 1));
	s[12] = xor3(s[12], t[1], ROTL64(t[3], 1));

	s[1] = ROTL64(s[6], 44);
	s[2] = ROTL64(s[12], 43);

	s[0] = chi(s[0], s[1], s[2]);

	/* iota: a[0,0] ^= round constant */
	//s[0] ^= vectorize(keccak_round_constants[23]);
	return s[0] ^ keccak_round_constants[23];
}

__device__ __forceinline__ void SHA3_512(uint2* s2) {

	uint64_t * s = (uint64_t*)s2; //dirty

	uint64_t t[5], u, v;

	for (uint32_t i = 9; i < 25; i++)
	{
		s[i] = 0;
	}
	s[8] = 0x8000000000000001;

	for (int i = 0; i < 23; i++)
	{
		/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
		t[0] = xor5(s[0], s[5], s[10], s[15], s[20]);
		t[1] = xor5(s[1], s[6], s[11], s[16], s[21]);
		t[2] = xor5(s[2], s[7], s[12], s[17], s[22]);
		t[3] = xor5(s[3], s[8], s[13], s[18], s[23]);
		t[4] = xor5(s[4], s[9], s[14], s[19], s[24]);

		/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
		/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

		u = ROTL64(t[1], 1);
		s[0] = xor3(s[0], t[4], u);
		s[5] = xor3(s[5], t[4], u);
		s[10] = xor3(s[10], t[4], u);
		s[15] = xor3(s[15], t[4], u);
		s[20] = xor3(s[20], t[4], u);

		u = ROTL64(t[2], 1);
		s[1] = xor3(s[1], t[0], u);
		s[6] = xor3(s[6], t[0], u);
		s[11] = xor3(s[11], t[0], u);
		s[16] = xor3(s[16], t[0], u);
		s[21] = xor3(s[21], t[0], u);

		u = ROTL64(t[3], 1);
		s[2] = xor3(s[2], t[1], u);
		s[7] = xor3(s[7], t[1], u);
		s[12] = xor3(s[12], t[1], u);
		s[17] = xor3(s[17], t[1], u);
		s[22] = xor3(s[22], t[1], u);

		u = ROTL64(t[4], 1);
		s[3] = xor3(s[3], t[2], u);
		s[8] = xor3(s[8], t[2], u);
		s[13] = xor3(s[13], t[2], u);
		s[18] = xor3(s[18], t[2], u);
		s[23] = xor3(s[23], t[2], u);


		u = ROTL64(t[0], 1);
		s[4] = xor3(s[4], t[3], u);
		s[9] = xor3(s[9], t[3], u);
		s[14] = xor3(s[14], t[3], u);
		s[19] = xor3(s[19], t[3], u);
		s[24] = xor3(s[24], t[3], u);

		/* rho pi: b[..] = rotl(a[..], ..) */
		u = s[1];

		s[1] = ROTL64(s[6], 44);
		s[6] = ROTL64(s[9], 20);
		s[9] = ROTL64(s[22], 61);
		s[22] = ROTL64(s[14], 39);
		s[14] = ROTL64(s[20], 18);
		s[20] = ROTL64(s[2], 62);
		s[2] = ROTL64(s[12], 43);
		s[12] = ROTL64(s[13], 25);
		s[13] = ROTL64(s[19], 8);
		s[19] = ROTL64(s[23], 56);
		s[23] = ROTL64(s[15], 41);
		s[15] = ROTL64(s[4], 27);
		s[4] = ROTL64(s[24], 14);
		s[24] = ROTL64(s[21], 2);
		s[21] = ROTL64(s[8], 55);
		s[8] = ROTL64(s[16], 45);
		s[16] = ROTL64(s[5], 36);
		s[5] = ROTL64(s[3], 28);
		s[3] = ROTL64(s[18], 21);
		s[18] = ROTL64(s[17], 15);
		s[17] = ROTL64(s[11], 10);
		s[11] = ROTL64(s[7], 6);
		s[7] = ROTL64(s[10], 3);
		s[10] = ROTL64(u, 1);

		/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */

		u = s[0]; v = s[1];
		s[0] = chi(s[0], s[1], s[2]);
		s[1] = chi(s[1], s[2], s[3]);
		s[2] = chi(s[2], s[3], s[4]);
		s[3] = chi(s[3], s[4], u);
		s[4] = chi(s[4], u, v);

		u = s[5]; v = s[6];
		s[5] = chi(s[5], s[6], s[7]);
		s[6] = chi(s[6], s[7], s[8]);
		s[7] = chi(s[7], s[8], s[9]);
		s[8] = chi(s[8], s[9], u);
		s[9] = chi(s[9], u, v);

		u = s[10]; v = s[11];
		s[10] = chi(s[10], s[11], s[12]);
		s[11] = chi(s[11], s[12], s[13]);
		s[12] = chi(s[12], s[13], s[14]);
		s[13] = chi(s[13], s[14], u);
		s[14] = chi(s[14], u, v);

		u = s[15]; v = s[16];
		s[15] = chi(s[15], s[16], s[17]);
		s[16] = chi(s[16], s[17], s[18]);
		s[17] = chi(s[17], s[18], s[19]);
		s[18] = chi(s[18], s[19], u);
		s[19] = chi(s[19], u, v);

		u = s[20]; v = s[21];
		s[20] = chi(s[20], s[21], s[22]);
		s[21] = chi(s[21], s[22], s[23]);
		s[22] = chi(s[22], s[23], s[24]);
		s[23] = chi(s[23], s[24], u);
		s[24] = chi(s[24], u, v);

		/* iota: a[0,0] ^= round constant */
		s[0] ^= keccak_round_constants[i];
	}

	/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
	t[0] = xor5(s[0], s[5], s[10], s[15], s[20]);
	t[1] = xor5(s[1], s[6], s[11], s[16], s[21]);
	t[2] = xor5(s[2], s[7], s[12], s[17], s[22]);
	t[3] = xor5(s[3], s[8], s[13], s[18], s[23]);
	t[4] = xor5(s[4], s[9], s[14], s[19], s[24]);

	/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
	/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */

	u = ROTL64(t[1], 1);
	s[0] = xor3(s[0], t[4], u);
	s[10] = xor3(s[10], t[4], u);

	u = ROTL64(t[2], 1);
	s[6] = xor3(s[6], t[0], u);
	s[16] = xor3(s[16], t[0], u);

	u = ROTL64(t[3], 1);
	s[12] = xor3(s[12], t[1], u);
	s[22] = xor3(s[22], t[1], u);

	u = ROTL64(t[4], 1);
	s[3] = xor3(s[3], t[2], u);
	s[18] = xor3(s[18], t[2], u);

	u = ROTL64(t[0], 1);
	s[9] = xor3(s[9], t[3], u);
	s[24] = xor3(s[24], t[3], u);

	/* rho pi: b[..] = rotl(a[..], ..) */
	u = s[1];

	s[1] = ROTL64(s[6], 44);
	s[6] = ROTL64(s[9], 20);
	s[9] = ROTL64(s[22], 61);
	s[2] = ROTL64(s[12], 43);
	s[4] = ROTL64(s[24], 14);
	s[8] = ROTL64(s[16], 45);
	s[5] = ROTL64(s[3], 28);
	s[3] = ROTL64(s[18], 21);
	s[7] = ROTL64(s[10], 3);

	/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */

	u = s[0]; v = s[1];
	s[0] = chi(s[0], s[1], s[2]);
	s[1] = chi(s[1], s[2], s[3]);
	s[2] = chi(s[2], s[3], s[4]);
	s[3] = chi(s[3], s[4], u);
	s[4] = chi(s[4], u, v);
	s[5] = chi(s[5], s[6], s[7]);
	s[6] = chi(s[6], s[7], s[8]);
	s[7] = chi(s[7], s[8], s[9]);

	/* iota: a[0,0] ^= round constant */
	s[0] ^= keccak_round_constants[23];
}