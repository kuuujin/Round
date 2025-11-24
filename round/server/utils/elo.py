def calculate_expected_score(rating_a, rating_b):
    return 1 / (1 + 10 ** ((rating_b - rating_a) / 400))

def calculate_new_ratings(rating_a, rating_b, actual_score_a, k_factor=32):
    expected_a = calculate_expected_score(rating_a, rating_b)
    expected_b = calculate_expected_score(rating_b, rating_a)
    
    actual_score_b = 1 - actual_score_a # A가 이기면(1) B는 지고(0), 비기면(0.5) 둘 다 0.5
    
    new_rating_a = rating_a + k_factor * (actual_score_a - expected_a)
    new_rating_b = rating_b + k_factor * (actual_score_b - expected_b)
    
    return int(round(new_rating_a)), int(round(new_rating_b))