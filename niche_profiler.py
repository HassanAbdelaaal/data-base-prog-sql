# ==============================================================================
# STRUCTURAL PROFILING AGENT (Python)
# This module implements the 4-step custom algorithm to generate a user's 
# qualitative Niche Profile Name (e.g., 'The Post-Modern Moralist').
# 
# NOTE: Uses a mock database connection/data structure for demonstration.
# In a real setup, pyodbc would be used to connect to MS SQL.
# ==============================================================================

import random
# import pyodbc # Uncomment in a real Node/Python environment

class ProfileGenerator:
    """
    Analyzes a user's viewing history and tag validations to synthesize a 
    unique qualitative Niche Profile name and description.
    """
    def __init__(self, viewer_id):
        self.viewer_id = viewer_id
        # Define the static pool of potential profile names for Step 3
        self.profile_names = {
            "Time & Narrative": ["The Chronological Conspirator", "The Non-Linear Auteur"],
            "Ethics & Character": ["The Post-Modern Moralist", "The Ambiguous Code Theorist"],
            "Form & Style": ["The Stylized Minimalist", "The Hyper-Visual Formalist"],
            "Density & Pacing": ["The High-Density Synthesizer", "The Measured Pacing Purist"],
        }
        
        # Mock database data (replace with actual database fetch)
        self.viewer_data = self._fetch_mock_data()


    def _fetch_mock_data(self):
        """
        Mocks the process of fetching the required data from the MS SQL database.
        
        In a real application, this would use pyodbc to execute T-SQL 
        queries to fetch viewing logs and tag validations for the viewer_id.
        """
        print(f"--- Simulating DB Fetch for Viewer {self.viewer_id} ---")

        # Mock Log Data: (asset_id, critical_rating, complexity_score, runtime_minutes)
        # Note: Crew, runtime, and other asset details would also be fetched here.
        mock_logs = [
            (1, 9, 5, 125, "Alex Chen"), # High rating, high complexity, Director: Alex Chen
            (3, 10, 4, 130, "Alex Chen"),
            (5, 7, 2, 95, None),
            (6, 8, 3, 120, "Bao Lin"),
            (7, 9, 5, 115, "Alex Chen"), # 3rd film by Alex Chen
        ]

        # Mock Strong Tag Validations (where agreement_intensity >= 4)
        # (tag_id, tag_name)
        mock_tags = [
            (1, 'Non-Linear Timeline'), # Time & Narrative
            (4, 'Unreliable Narrator'), # Ethics & Character
            (6, 'High Conceptual Density'), # Density & Pacing
            (1, 'Non-Linear Timeline'), # Confirmation
            (4, 'Unreliable Narrator'), 
            (7, 'Stylized Minimalist'), # Form & Style
        ]
        
        return {
            'logs': mock_logs,
            'tags': mock_tags
        }


    # ----------------------------------------------------------------------
    # STEP 1: Data Aggregation
    # Creates lists of key characteristics based on high-rated media.
    # ----------------------------------------------------------------------
    def step_1_aggregate_data(self):
        """Aggregates characteristics of films the user rated >= 8."""
        
        # Filter logs for highly-rated media
        high_rated_logs = [log for log in self.viewer_data['logs'] if log[1] >= 8]
        
        # Aggregate categories
        aggregated_data = {
            'directors': {},
            'runtimes': [], # Collect all runtimes of highly-rated films
            'complexity_sum': 0
        }

        for _, rating, complexity, runtime, director in high_rated_logs:
            # Director Style Aggregation
            if director:
                aggregated_data['directors'][director] = aggregated_data['directors'].get(director, 0) + 1
            
            # Runtime Aggregation
            aggregated_data['runtimes'].append(runtime)
            
            # Complexity Aggregation
            aggregated_data['complexity_sum'] += complexity

        return aggregated_data, high_rated_logs


    # ----------------------------------------------------------------------
    # STEP 2: Crossover Pattern Recognition
    # Looks for patterns appearing in 3 or more high-rated films.
    # ----------------------------------------------------------------------
    def step_2_crossover_patterns(self, aggregated_data, high_rated_logs):
        """Identifies patterns across structural tags, crew, and duration."""
        
        crossover_patterns = {}
        
        # A. Structural Tag Patterns (Directly from ViewerTagValidation)
        # Group tags by their conceptual category to form a structural axis
        tag_categories = {
            1: "Time & Narrative", 4: "Ethics & Character", 6: "Density & Pacing",
            2: "Dialogue & Pacing", 5: "Form & Style", 7: "Form & Style", 3: "Ethics & Character"
        }
        
        # Count the frequency of the conceptual categories
        tag_category_counts = {}
        for tag_id, tag_name in self.viewer_data['tags']:
            category = tag_categories.get(tag_id)
            tag_category_counts[category] = tag_category_counts.get(category, 0) + 1
        
        # Identify the most dominant category
        dominant_category = max(tag_category_counts, key=tag_category_counts.get)
        crossover_patterns['dominant_category'] = dominant_category

        # B. Crew/Director Style
        # Find directors credited in 3 or more high-rated films
        dominant_directors = [d for d, count in aggregated_data['directors'].items() if count >= 3]
        if dominant_directors:
            crossover_patterns['dominant_crew'] = dominant_directors[0]
            
        # C. Runtime and Complexity Pattern
        avg_runtime = sum(aggregated_data['runtimes']) / len(aggregated_data['runtimes']) if aggregated_data['runtimes'] else 0
        avg_complexity = aggregated_data['complexity_sum'] / len(high_rated_logs) if high_rated_logs else 0

        crossover_patterns['pacing'] = 'Long-Form' if avg_runtime >= 115 else 'Standard Pacing'
        crossover_patterns['complexity_level'] = 'High' if avg_complexity >= 4 else 'Medium'

        return crossover_patterns


    # ----------------------------------------------------------------------
    # STEP 3: Synthesis and Naming
    # Creates the unique Niche Profile Name based on the dominant axis.
    # ----------------------------------------------------------------------
    def step_3_synthesize_name(self, crossover_patterns):
        """Generates the profile name and provides a summary."""
        
        dominant_category = crossover_patterns.get('dominant_category')
        complexity_level = crossover_patterns.get('complexity_level')
        
        # 1. Select the base name based on the dominant structural axis
        base_names = self.profile_names.get(dominant_category, self.profile_names['Ethics & Character'])
        
        # 2. Refine the name based on the Complexity Level
        if complexity_level == 'High' and len(base_names) > 1:
            # Choose the more conceptually dense name (e.g., 'The Theorist' over 'The Judge')
            profile_name = base_names[0]
        else:
            profile_name = base_names[1]

        # 3. Generate the summary (explaining the "why")
        summary = (
            f"Your core niche is the **{dominant_category}** axis. You consistently validate "
            f"tags related to complex structure ({crossover_patterns['complexity_level']} complexity) and show "
            f"a preference for films in the {crossover_patterns['pacing']} runtime range. "
        )
        if 'dominant_crew' in crossover_patterns:
             summary += f"You have a significant affinity for the style of **{crossover_patterns['dominant_crew']}**."

        return profile_name, summary

    # ----------------------------------------------------------------------
    # STEP 4: Potential Outlier Interpretation
    # Identifies films rated highly that do NOT fit the dominant niche.
    # ----------------------------------------------------------------------
    def step_4_outlier_interpretation(self, high_rated_logs, profile_name):
        """Finds high-rated films that are outside the predicted niche."""
        
        # Placeholder logic: Find films with low complexity or short runtimes
        # In reality, this would involve comparing asset tags against the user's top bias tags
        
        outliers = [
            f"Asset ID {log[0]} (Rated {log[1]})" 
            for log in high_rated_logs 
            if log[2] <= 2 or log[3] < 100
        ]
        
        if outliers:
            outlier_report = (
                f"**Outlier Insight:** While you are profiled as '{profile_name}', you show flexibility. "
                f"You highly rated {len(outliers)} media assets ({', '.join(outliers[:2])}...) that fall outside your structural profile, "
                f"suggesting a tolerance for quality even when the form is simple."
            )
        else:
            outlier_report = "Your viewing habits are highly consistent with your niche profile."

        return outlier_report


    # ----------------------------------------------------------------------
    # Main Execution Method
    # ----------------------------------------------------------------------
    def generate_profile(self):
        """Executes the full 4-step algorithm."""
        
        # Step 1
        aggregated_data, high_rated_logs = self.step_1_aggregate_data()
        
        # Guard clause for new users
        if not high_rated_logs:
            return "Profile Not Available", "Log at least 3 films rated 8 or higher to generate your Structural Profile."
            
        # Step 2
        crossover_patterns = self.step_2_crossover_patterns(aggregated_data, high_rated_logs)
        
        # Step 3
        profile_name, summary = self.step_3_synthesize_name(crossover_patterns)
        
        # Step 4
        outlier_report = self.step_4_outlier_interpretation(high_rated_logs, profile_name)
        
        return profile_name, summary, outlier_report

# Example usage (for local testing)
if __name__ == '__main__':
    # Initialize the generator with a mock viewer ID
    profiler = ProfileGenerator(viewer_id=1001)
    name, summary, report = profiler.generate_profile()
    
    print("\n=======================================================")
    print(f"GENERATED STRUCTURAL NICHE PROFILE FOR VIEWER {profiler.viewer_id}")
    print("=======================================================")
    print(f"Niche Profile Name: {name}")
    print("-------------------------------------------------------")
    print(f"Summary:\n{summary}")
    print(f"\nReport:\n{report}")
    print("=======================================================\n")