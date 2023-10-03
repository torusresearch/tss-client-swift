#ifndef __DKLS_H__
#define __DKLS_H__ // Include guard
    #ifdef __cplusplus // Required for C++ compiler
    extern "C" {
    #endif
        //Includes
        #include <stdarg.h>
        #include <stdbool.h>
        #include <stdint.h>
        #include <stdlib.h>

        //Forward declarations
        struct Sigfrags;
        struct Counterparties;
        struct DKLSMsgComm;
        struct ChaChaRng;
        struct ThresholdSigner;
        struct Precompute;

        //Methods
        //Signature Fragments
        struct Sigfrags *signature_fragments_from_string(const char* input, int* error_code);
        const char* signature_fragments_to_string(struct Sigfrags* fragments, int* error_code);
        void signature_fragments_free(struct Sigfrags* fragments);

        //Counterparties
        struct Counterparties *counterparties_from_string(const char* parties, int* error_code);
        const char* counterparties_to_string(struct Counterparties* fragments, int* error_code);
        void counterparties_free(struct Counterparties* parties);

        //MsgComm
        struct DKLSMsgComm* dkls_comm(int index,int parties,const char* session,
        const char* (*read_msg_callback)(const char*,unsigned long long int,unsigned long long int,const char*, const void*),
        bool (*send_msg_callback)(const char*,unsigned long long int,unsigned long long int,const char*,const char*, const void*), const void* parent_instance_ref, int* error_code);
        const void* dkls_comm_free(struct DKLSMsgComm* comm);

        //Random Generator
        struct ChaChaRng* random_generator(const char* state, int* error_code);
        void random_generator_free(struct ChaChaRng* rng);

        //Precompute
        const char* precompute_to_string(struct Precompute* precompute, int* error_code);
        struct Precompute* precompute_from_string(const char* input, int* error_code);
        const char* get_r_from_precompute(const char* precompute, int* error_code);
        void precompute_free(struct Precompute* precompute);

        //Threshold Signer
        struct ThresholdSigner* threshold_signer(const char* session, int player_index, int parties, int threshold, const char* share, const char* pubkey, int* error_code);
        void threshold_signer_free(struct ThresholdSigner* signer);
        bool threshold_signer_setup(struct ThresholdSigner* signer, struct ChaChaRng* rng, struct DKLSMsgComm* comm);
        const char* threshold_signer_precompute(struct Counterparties* parties, struct ThresholdSigner* signer, struct ChaChaRng* rng, struct DKLSMsgComm* comm, int* error_code);
        const char* threshold_signer_sign(struct Counterparties* counterparties, const char* msg, bool hash_only, struct ThresholdSigner* signer, struct ChaChaRng* rng, struct DKLSMsgComm* comm, int* error_code);

        //Utilities
        int dkls_batch_size(int* error_code);
        const char* dkls_hash_encode(const char* msg, int* error_code);
        const char* dkls_local_sign(const char* msg, bool hash_only, const char* precompute, int* error_code);
        const char* dkls_local_verify(const char* msg, bool hash_only, const char* r, struct Sigfrags* sig_frags, const char* pubkey, int* error_code);
        void dkls_string_free(char* ptr);
    #ifdef __cplusplus
    } // extern "C"
    #endif
#endif // __DKLS_H__
