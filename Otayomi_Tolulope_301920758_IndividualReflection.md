# Individual reflection

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

One challenge I faced was interpreting the assessment requirements and understanding how the five portfolio activities should fit together. Separating the requirements into individual deliverables helped make the scope clearer while keeping the same guesthouse case throughout. The distinction between implemented work and a proposed design was particularly important for the cloud portfolio.

MongoDB configuration also proved difficult to get right during the first few attempts. The working setup uses a separate local process, a dedicated port and a project-specific database. A successful connection check established that the server was reachable; document validation and comparison with the PostgreSQL records then checked different aspects of the stored data. This distinction matters because connecting successfully does not, by itself, establish that the data model or results are correct.

Calculating booking value for a particular month, especially December, was another tricky part of the implementation. A stay can cross into the next month, so assigning its entire value to the arrival month would overstate that month's total. For example, a stay from 31 December to 3 January at NGN 40,000 per night has a full value of NGN 120,000, but only NGN 40,000 belongs to December. The reporting query counts only nights within the reporting period, excludes the departure date and leaves cancelled bookings out of the active total. This example clarifies why booking value for a month can differ from the total value of the reservations included in the report.
