import random

def generate_test_cases(filename,
                        num_tests=10,
                        vec_len=4,
                        scalar_bits=8):
    max_val = (1 << scalar_bits) - 1

    with open(filename, 'w') as f:
        for _ in range(num_tests):
            vec_a = [random.randint(0, max_val) for _ in range(vec_len)]
            vec_b = [random.randint(0, max_val) for _ in range(vec_len)]
            dot_product = sum(a * b for a, b in zip(vec_a, vec_b))
            a_str = " ".join(str(x) for x in vec_a)
            b_str = " ".join(str(x) for x in vec_b)
            f.write(f"[{a_str}] [{b_str}] {dot_product}\n")

# Example usage:
generate_test_cases("test_vectors_dot_product_8bit.txt", num_tests=20, vec_len=8, scalar_bits=8)
